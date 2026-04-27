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
    // MARK: - Public

    var title: String {
        get { label.stringValue }
        set { label.stringValue = newValue }
    }

    var onAction: (() -> Void)?

    // MARK: - Private

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

    // MARK: - Init

    init(title: String = "") {
        super.init(frame: .zero)
        label.stringValue = title
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
        backgroundLayer.backgroundColor = NSColor.clear.cgColor

        layer?.cornerRadius = Const.btnRadius
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        layer?.insertSublayer(backgroundLayer, at: 0)

        addSubview(label)
        label.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(Const.space10)
        }

        snp.makeConstraints { make in
            make.height.equalTo(24)
        }
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

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        layer?.borderColor = NSColor.separatorColor.cgColor
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
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.12)
        backgroundLayer.backgroundColor = NSColor.labelColor.withAlphaComponent(0.03).cgColor
        CATransaction.commit()
        NSCursor.pointingHand.push()
    }

    override func mouseExited(with _: NSEvent) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.06)
        backgroundLayer.backgroundColor = NSColor.clear.cgColor
        CATransaction.commit()
        NSCursor.pop()
    }

    // MARK: - Click

    override func mouseDown(with event: NSEvent) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundLayer.backgroundColor = NSColor.labelColor.withAlphaComponent(0.07).cgColor
        CATransaction.commit()
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundLayer.backgroundColor = NSColor.labelColor.withAlphaComponent(0.03).cgColor
        CATransaction.commit()

        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) {
            onAction?()
        }
        super.mouseUp(with: event)
    }
}
