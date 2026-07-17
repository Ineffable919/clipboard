//
//  PreviewIconButton.swift
//  Clipboard
//
//  预览区域通用图标按钮（带 hover 背景效果）
//

import AppKit
import SnapKit

final class PreviewIconButton: NSView {
    var onAction: (() -> Void)?

    private let imageView = NSImageView()
    private let backgroundLayer = CALayer()
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    init(systemSymbol: String, accessibilityDescription: String? = nil) {
        super.init(frame: .zero)
        imageView.image = NSImage(systemSymbolName: systemSymbol, accessibilityDescription: accessibilityDescription)
        imageView.contentTintColor = .controlTextColor
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func updateSymbol(_ name: String, accessibilityDescription: String? = nil) {
        imageView.image = NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription)
    }

    private func setup() {
        wantsLayer = true
        backgroundLayer.cornerRadius = Const.btnRadius
        backgroundLayer.cornerCurve = .continuous
        layer?.insertSublayer(backgroundLayer, at: 0)

        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(16)
        }
        snp.makeConstraints { make in
            make.width.height.equalTo(24)
        }
        updateAppearance(animated: false)
    }

    override var acceptsFirstResponder: Bool {
        false
    }

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance(animated: false)
    }

    private func updateAppearance(animated: Bool) {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let bgColor: NSColor = isHovering
            ? (isDark ? .white.withAlphaComponent(0.08) : .black.withAlphaComponent(0.06))
            : .clear

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

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = trackingArea {
            removeTrackingArea(old)
        }
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

    override func mouseDown(with event: NSEvent) {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let pressedColor: NSColor = isDark
            ? .white.withAlphaComponent(0.14)
            : .black.withAlphaComponent(0.10)
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
