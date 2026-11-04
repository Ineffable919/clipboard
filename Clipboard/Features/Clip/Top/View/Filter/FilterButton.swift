//
//  FilterButton.swift
//  Clipboard
//
//  Created by crown on 2026/4/9
//

import AppKit

/// 筛选按钮：继承 NSButton 以获得标准的按钮无障碍角色与按压语义，外观自绘
class FilterButton: NSButton {
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

    var onTap: (() -> Void)?

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

    private func setup(icon: String?, title labelText: String) {
        wantsLayer = true
        isBordered = false
        title = ""
        // 保持原有焦点行为：弹窗内不接管第一响应者
        refusesFirstResponder = true
        target = self
        action = #selector(handleClick)
        setAccessibilityLabel(labelText)

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

        setupLabel(labelText)

        updateAppearance(animated: false)
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
        label.setAccessibilityElement(false)
        addSubview(label)
    }

    func setLeadingView(_ view: NSView) {
        leadingView = view
        view.setAccessibilityElement(false)
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
            label.textColor = .labelColor
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
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.12)
            backgroundLayer.backgroundColor = bgColor.cgColor
            CATransaction.commit()
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            backgroundLayer.backgroundColor = bgColor.cgColor
            CATransaction.commit()
        }
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds

        // 尚未分配尺寸（如隐藏的按钮）时 insetBy 会返回 null 矩形，origin 为无穷大
        guard bounds.width > Const.space8 * 2, bounds.height > Const.space4 * 2 else { return }
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

        // 文本被截断时悬停显示完整文案
        let tip = textSize.width > textWidth ? label.stringValue : nil
        if toolTip != tip { toolTip = tip }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance(animated: false)
    }

    /// 用光标矩形代替 push/pop，视图被移除时不会遗留光标栈
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    // MARK: - Hit Testing

    /// 子视图（文案、图标）不单独响应点击，整个按钮区域统一由自身处理
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    // MARK: - Action

    @objc private func handleClick() {
        onTap?()
    }

    // MARK: - Accessibility

    override func isAccessibilitySelected() -> Bool {
        isSelected
    }
}
