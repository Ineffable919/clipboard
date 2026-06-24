//
//  PreviewPillButton.swift
//  Clipboard
//
//  预览区域通用胶囊按钮
//

import AppKit
import SnapKit

// MARK: - PreviewPillButton

final class PreviewPillButton: NSView {
    // MARK: - Style

    enum Style {
        case secondary
        case primary
    }

    // MARK: - Public

    var title: String {
        get { label.stringValue }
        set { label.stringValue = newValue }
    }

    var onAction: (() -> Void)?

    // MARK: - Private

    private let style: Style

    private let label: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = .systemFont(ofSize: NSFont.systemFontSize)
        f.textColor = .controlTextColor
        f.lineBreakMode = .byTruncatingTail
        f.cell?.truncatesLastVisibleLine = true
        return f
    }()

    private let backgroundLayer = CALayer()
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    // MARK: - Init

    init(title: String = "", style: Style = .secondary) {
        self.style = style
        super.init(frame: .zero)
        label.stringValue = title
        label.textColor = style == .primary ? .white : .controlTextColor
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true

        backgroundLayer.cornerRadius = Const.btnRadius
        backgroundLayer.cornerCurve = .continuous
        layer?.cornerRadius = Const.btnRadius
        layer?.cornerCurve = .continuous
        layer?.borderWidth = style == .secondary ? 0.5 : 0
        layer?.insertSublayer(backgroundLayer, at: 0)

        addSubview(label)
        label.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(Const.space10)
        }

        snp.makeConstraints { make in
            make.height.equalTo(22)
        }

        updateAppearance(animated: false)
    }

    // MARK: - First Responder

    override var acceptsFirstResponder: Bool {
        false
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
    }

    // MARK: - Appearance

    private func updateAppearance(animated: Bool) {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let bgColor: NSColor
        switch style {
        case .secondary:
            bgColor = isHovering
                ? (isDark ? .white.withAlphaComponent(0.08) : .black.withAlphaComponent(0.06))
                : .clear
            let borderColor: NSColor = isDark
                ? .white.withAlphaComponent(0.2)
                : .separatorColor
            layer?.borderColor = borderColor.cgColor
        case .primary:
            bgColor = isHovering
                ? .controlAccentColor.blended(withFraction: 0.12, of: .black) ?? .controlAccentColor
                : .controlAccentColor
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

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance(animated: false)
    }

    // MARK: - Tracking

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = trackingArea { removeTrackingArea(old) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with _: NSEvent) {
        isHovering = true
        updateAppearance(animated: true)
        NSCursor.pointingHand.push()
    }

    override func mouseExited(with _: NSEvent) {
        isHovering = false
        updateAppearance(animated: true)
        NSCursor.pop()
    }

    // MARK: - Click

    override func mouseDown(with event: NSEvent) {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let pressedColor: NSColor
        switch style {
        case .secondary:
            pressedColor = isDark
                ? .white.withAlphaComponent(0.14)
                : .black.withAlphaComponent(0.10)
        case .primary:
            pressedColor = .controlAccentColor.blended(withFraction: 0.2, of: .black) ?? .controlAccentColor
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundLayer.backgroundColor = pressedColor.cgColor
        CATransaction.commit()
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        updateAppearance(animated: false)

        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) {
            onAction?()
        }
        super.mouseUp(with: event)
    }
}
