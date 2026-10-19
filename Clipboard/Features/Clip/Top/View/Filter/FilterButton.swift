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
    private let iconImageView = NSImageView()
    private let label = NSTextField()
    private var leadingView: NSView?

    var isSelected: Bool = false {
        didSet {
            guard oldValue != isSelected else { return }
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

        if let icon {
            let symConfig = NSImage.SymbolConfiguration(
                pointSize: 16,
                weight: .regular
            )
            iconImageView.image = NSImage(
                systemSymbolName: icon,
                accessibilityDescription: nil
            )?.withSymbolConfiguration(symConfig)
            iconImageView.imageScaling = .scaleProportionallyDown
            setLeadingView(iconImageView)
        }

        setupLabel(title)

        setupTracking()

        updateAppearance(animated: false)
    }

    private func setupTracking() {
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

    }

    private func setupLabel(_ title: String) {
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
        addSubview(label)

    }

    func setLeadingView(_ view: NSView) {
        leadingView = view
        addSubview(view)
        needsLayout = true
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
        } else if effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            .white.withAlphaComponent(0.08)
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
        let textSize = label.intrinsicContentSize
        let iconWidth: CGFloat = leadingView == nil ? 0 : 20 + Const.space8
        let fitting = NSSize(
            width: textSize.width + iconWidth + Const.space8,
            height: max(textSize.height, leadingView == nil ? 0 : 20)
        )
        return NSSize(
            width: fitting.width + Const.space10 * 2,
            height: fitting.height + Const.space6 * 2
        )
    }

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds

        let contentRect = bounds.insetBy(dx: Const.space8, dy: Const.space4)
        var textX = contentRect.minX
        if let leadingView {
            leadingView.frame = NSRect(
                x: contentRect.minX,
                y: contentRect.midY - 10,
                width: 20,
                height: 20
            )
            textX += 20 + Const.space8
        }

        let textSize = label.intrinsicContentSize
        // 保留原尾部 spacer 前的间距，避免改变文案截断位置
        let textWidth = max(0, contentRect.maxX - textX - Const.space8)
        label.frame = NSRect(
            x: textX,
            y: contentRect.midY - textSize.height / 2,
            width: textWidth,
            height: textSize.height
        )
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
