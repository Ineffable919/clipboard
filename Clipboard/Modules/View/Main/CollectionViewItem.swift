//
//  CollectionViewItem.swift
//  Clipboard
//
//  Created by crown on 2026/4/10.
//

import AppKit
import CoreFoundation
import SnapKit

final class CollectionViewItem: NSCollectionViewItem {
    private var item: PasteboardModel?
    private var iconLoadTask: Task<Void, Never>?
    private var isFocused = true

    // MARK: - Head

    private lazy var headView: CardHeadView = .init()

    // MARK: - Selection border

    private lazy var selectionBorderView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.masksToBounds = false
        view.layer?.backgroundColor = .clear
        view.layer?.cornerRadius = Const.radius + Const.selectionBorderWidth
        view.layer?.cornerCurve = .continuous
        view.layer?.borderWidth = 0
        return view
    }()

    private lazy var contentView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = .clear
        view.layer?.cornerRadius = Const.radius
        view.layer?.cornerCurve = .continuous
        return view
    }()

    private lazy var label: NSTextField = {
        let field = NSTextField(wrappingLabelWithString: "")
        field.wantsLayer = true
        field.layer?.backgroundColor = .clear
        field.font = .systemFont(ofSize: 14)
        field.isEditable = false
        field.isSelectable = false
        field.textColor = .textColor
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }()

    func configure(with model: PasteboardModel) {
        item = model

        headView.configure(with: model)

        if model.pasteboardType.isText() {
            guard let att = item?.attributeString else { return }
            if att.length > 0,
               let color = att.attribute(
                   .backgroundColor,
                   at: 0,
                   effectiveRange: nil
               ) as? NSColor
            {
                label.attributedStringValue = att
                contentView.layer?.backgroundColor = color.cgColor
            } else {
                label.stringValue = att.string
                contentView.layer?.backgroundColor =
                    NSColor.textBackgroundColor.cgColor
            }
        }
    }

    func setFocused(_ focused: Bool) {
        isFocused = focused
        updateSelectionBorder()
    }
}

// MARK: - 生命周期

extension CollectionViewItem {
    override func viewDidLoad() {
        super.viewDidLoad()
        initSubView()
    }

    override var isSelected: Bool {
        didSet {
            updateSelectionBorder()
        }
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if event.type == .leftMouseDown, event.clickCount == 2 {}
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconLoadTask?.cancel()
        iconLoadTask = nil
        headView.reset()
    }

    private func updateSelectionBorder() {
        guard isSelected else {
            selectionBorderView.layer?.borderWidth = 0
            return
        }
        let color: NSColor = isFocused
            ? .controlAccentColor.withAlphaComponent(0.8)
            : .gray.withAlphaComponent(0.5)
        selectionBorderView.layer?.borderColor = color.cgColor
        selectionBorderView.layer?.borderWidth = Const.selectionBorderWidth
    }
}

// MARK: - UI

extension CollectionViewItem {
    func initSubView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear

        view.addSubview(selectionBorderView)
        selectionBorderView.addSubview(contentView)
        contentView.addSubview(headView)
        contentView.addSubview(label)

        selectionBorderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Const.selectionBorderWidth)
        }

        headView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Const.hdSize)
        }

        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Const.space10)
            make.trailing.equalToSuperview().offset(-Const.space8)
            make.top.equalTo(headView.snp.bottom).offset(Const.space8)
            make.bottom.lessThanOrEqualToSuperview().offset(-Const.space8)
        }
    }
}

extension CollectionViewItem: UserInterfaceItemIdentifier {}
