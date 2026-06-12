//
//  FilterButton.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit
import SnapKit
import SwiftUI

class FilterButton: NSView {
    // MARK: - Properties

    private let backgroundLayer = CALayer()
    let stack = NSStackView()
    private let iconImageView = NSImageView()
    private let label = NSTextField()
    private var hasIcon = false

    var isSelected: Bool = false {
        didSet {
            updateAppearance(animated: true)
        }
    }

    var action: (() -> Void)?

    // MARK: - Init

    init(icon: String? = nil, title: String) {
        super.init(frame: .zero)
        setup(icon: icon, title: title)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Setup

    private func setup(icon: String?, title: String) {
        wantsLayer = true

        backgroundLayer.cornerRadius = Const.radius
        backgroundLayer.masksToBounds = true
        layer?.addSublayer(backgroundLayer)

        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = Const.space8
        addSubview(stack)

        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(
                NSEdgeInsets(
                    top: Const.space4,
                    left: Const.space8,
                    bottom: Const.space4,
                    right: Const.space8
                )
            )
        }

        if let icon {
            hasIcon = true
            let symConfig = NSImage.SymbolConfiguration(
                pointSize: 16,
                weight: .regular
            )
            iconImageView.image = NSImage(
                systemSymbolName: icon,
                accessibilityDescription: nil
            )?.withSymbolConfiguration(symConfig)
            iconImageView.imageScaling = .scaleProportionallyDown
            iconImageView.snp.makeConstraints { make in
                make.width.height.equalTo(20)
            }
            stack.addArrangedSubview(iconImageView)
        }

        label.stringValue = title
        label.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        label.isBordered = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.cell?.usesSingleLineMode = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(label)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)

        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)

        let click = NSClickGestureRecognizer(
            target: self,
            action: #selector(handleClick)
        )
        addGestureRecognizer(click)

        updateAppearance(animated: false)
    }

    // MARK: - Appearance

    private func updateAppearance(animated: Bool) {
        // 文本和图标颜色
        if isSelected {
            label.textColor = .white
            iconImageView.contentTintColor = .white
        } else {
            label.textColor = .secondaryLabelColor
            iconImageView.contentTintColor = .secondaryLabelColor
        }

        // 背景颜色
        let bgColor: NSColor = if isSelected {
            .controlAccentColor
        } else {
            NSColor.secondaryLabelColor.withAlphaComponent(0.05)
        }

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                ctx.allowsImplicitAnimation = true
                backgroundLayer.backgroundColor = bgColor.cgColor
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            backgroundLayer.backgroundColor = bgColor.cgColor
            CATransaction.commit()
        }
    }

    // MARK: - Layout

    override var intrinsicContentSize: NSSize {
        let fitting = stack.fittingSize
        return NSSize(
            width: fitting.width + Const.space10 * 2,
            height: fitting.height + Const.space6 * 2
        )
    }

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance(animated: false)
    }

    // MARK: - Mouse

    override func mouseEntered(with _: NSEvent) {
        NSCursor.pointingHand.push()
    }

    override func mouseExited(with _: NSEvent) {
        NSCursor.pop()
    }

    // MARK: - Action

    @objc private func handleClick() {
        action?()
    }

    override var acceptsFirstResponder: Bool {
        false
    }

    override func becomeFirstResponder() -> Bool {
        false
    }
}
