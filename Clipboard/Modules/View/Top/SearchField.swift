//
//  SearchField.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit
import Combine
import SnapKit

final class SearchField: NSView {
    @Published private(set) var text: String = ""

    var onResignFirstResponder: (() -> Void)?

    var onBecomeFirstResponder: (() -> Void)?

    var onClear: (() -> Void)?

    /// 控制搜索框是否接受焦点
    var acceptsFocus: Bool = false {
        didSet { textField.canAcceptFocus = acceptsFocus }
    }

    /// 控制焦点环
    var suppressFocusRing: Bool = false {
        didSet {
            textField.suppressFocusRing = suppressFocusRing
        }
    }

    var stringValue: String {
        get { textField.stringValue }
        set { textField.stringValue = newValue }
    }

    var placeholderString: String? {
        get { textField.placeholderString }
        set { textField.placeholderString = newValue }
    }

    var isFirstResponder: Bool {
        textField.currentEditor() != nil
            && textField.currentEditor() == window?.firstResponder
    }

    override var canBecomeKeyView: Bool {
        acceptsFocus
    }

    override var acceptsFirstResponder: Bool {
        acceptsFocus
    }

    override var focusRingType: NSFocusRingType {
        get { .none }
        set {}
    }

    override func becomeFirstResponder() -> Bool {
        guard acceptsFocus else { return false }
        window?.makeFirstResponder(textField)
        return true
    }

    // MARK: - Subviews

    private let searchIcon = NSImageView()
    private let textField = InnerTextField()
    private let cancelButton = NSButton()

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = Const.topRadius
        updateColors()

        setupSearchIcon()
        setupCancelButton()
        setupTextField()
    }

    private func setupSearchIcon() {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        searchIcon.image = NSImage(
            systemSymbolName: "magnifyingglass",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(config)
        searchIcon.contentTintColor = .secondaryLabelColor
        addSubview(searchIcon)

        searchIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
        }
    }

    private func setupCancelButton() {
        cancelButton.bezelStyle = .inline
        cancelButton.isBordered = false
        cancelButton.refusesFirstResponder = true
        cancelButton.image = NSImage(
            systemSymbolName: "xmark.circle.fill",
            accessibilityDescription: nil
        )
        cancelButton.contentTintColor = .secondaryLabelColor
        cancelButton.target = self
        cancelButton.action = #selector(clear)
        cancelButton.isHidden = true
        addSubview(cancelButton)

        cancelButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }
    }

    private func setupTextField() {
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .default
        textField.font = .systemFont(ofSize: 14)
        textField.placeholderString = String(localized: .search)
        textField.cell?.isScrollable = true
        textField.cell?.wraps = false
        textField.cell?.usesSingleLineMode = true
        textField.delegate = self
        textField.containerCornerRadius = Const.topRadius
        textField.onBecomeFirstResponder = { [weak self] in self?.onBecomeFirstResponder?() }
        textField.onResignFirstResponder = { [weak self] in self?.onResignFirstResponder?() }
        addSubview(textField)

        textField.snp.makeConstraints { make in
            make.leading.equalTo(searchIcon.snp.trailing).offset(4)
            make.trailing.equalTo(cancelButton.snp.leading).offset(-6)
            make.centerY.equalToSuperview()
        }
    }

    // MARK: - Appearance

    override func updateLayer() {
        super.updateLayer()
        updateColors()
    }

    private func updateColors() {
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
    }

    // MARK: - Actions

    @objc func clear() {
        textField.stringValue = ""
        text = ""
        cancelButton.isHidden = true
        onClear?()
    }
}

// MARK: - NSTextFieldDelegate

extension SearchField: NSTextFieldDelegate {
    func controlTextDidChange(_: Notification) {
        let value = textField.stringValue
        if value != text {
            text = value
        }
        cancelButton.isHidden = value.isEmpty
    }

    func controlTextDidEndEditing(_: Notification) {
        onResignFirstResponder?()
    }
}

// MARK: - InnerTextField

private final class InnerTextField: NSTextField {
    var containerCornerRadius: CGFloat = Const.radius
    var canAcceptFocus: Bool = false
    var suppressFocusRing: Bool = false
    var onBecomeFirstResponder: (() -> Void)?
    var onResignFirstResponder: (() -> Void)?

    override var canBecomeKeyView: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        canAcceptFocus
    }

    override var focusRingType: NSFocusRingType {
        get { suppressFocusRing ? .none : .exterior }
        set {}
    }

    override var focusRingMaskBounds: NSRect {
        guard let container = superview else { return bounds }
        return container.convert(container.bounds, to: self)
    }

    override func drawFocusRingMask() {
        let maskRect = focusRingMaskBounds
        NSBezierPath(
            roundedRect: maskRect,
            xRadius: containerCornerRadius,
            yRadius: containerCornerRadius
        ).fill()
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            if !suppressFocusRing {
                noteFocusRingMaskChanged()
            }
            onBecomeFirstResponder?()
            if let editor = currentEditor() {
                let end = editor.string.endIndex
                let nsRange = NSRange(end..., in: editor.string)
                editor.selectedRange = nsRange
            }
        }
        return result
    }
}
