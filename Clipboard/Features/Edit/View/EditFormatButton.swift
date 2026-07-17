//
//  EditFormatButton.swift
//  Clipboard
//
//  编辑工具栏格式化图标按钮（加粗 / 斜体 / 下划线 / 删除线）
//

import AppKit
import SnapKit

final class EditFormatButton: NSView {
    // MARK: - Public

    var action: (() -> Void)?

    // MARK: - Private

    private let backgroundLayer = CALayer()
    private let imageView = NSImageView()
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    // MARK: - Init

    init(symbolName: String) {
        super.init(frame: .zero)
        setup(symbolName: symbolName)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Setup

    private func setup(symbolName: String) {
        wantsLayer = true

        backgroundLayer.cornerRadius = Const.settingsRadius
        backgroundLayer.cornerCurve = .continuous
        layer?.addSublayer(backgroundLayer)

        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        imageView.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(config)
        imageView.contentTintColor = .labelColor
        imageView.imageScaling = .scaleProportionallyDown
        addSubview(imageView)

        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        snp.makeConstraints { make in
            make.width.equalTo(28)
            make.height.equalTo(24)
        }

        updateAppearance(animated: false)
    }

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

        let bgColor: NSColor = isHovering
            ? (isDark ? .white.withAlphaComponent(0.08) : .black.withAlphaComponent(0.06))
            : .clear

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.1
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
    }

    override func mouseExited(with _: NSEvent) {
        isHovering = false
        updateAppearance(animated: true)
    }

    // MARK: - Click

    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) {
            action?()
        }
        super.mouseUp(with: event)
    }
}
