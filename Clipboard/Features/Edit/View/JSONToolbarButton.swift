//
//  JSONToolbarButton.swift
//  Clipboard
//

import AppKit
import SnapKit

final class JSONToolbarButton: NSButton {
    var popupMenu: NSMenu?

    private var trackingAreaReference: NSTrackingArea?
    private var isHovering = false

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(
            width: size.width + Const.space6 * 2,
            height: size.height
        )
    }

    init(title: String, showsMenuIndicator: Bool = false) {
        super.init(frame: .zero)
        setup(title: title, showsMenuIndicator: showsMenuIndicator)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    private func setup(title: String, showsMenuIndicator: Bool) {
        self.title = title
        bezelStyle = .inline
        isBordered = false
        refusesFirstResponder = true
        contentTintColor = .labelColor
        controlSize = .small
        font = .systemFont(ofSize: 12)
        imagePosition = .imageTrailing
        imageHugsTitle = true

        if showsMenuIndicator {
            let configuration = NSImage.SymbolConfiguration(
                pointSize: 9,
                weight: .semibold
            )
            image = NSImage(
                systemSymbolName: "chevron.down",
                accessibilityDescription: nil
            )?.withSymbolConfiguration(configuration)
        }

        setContentHuggingPriority(.required, for: .horizontal)
        snp.makeConstraints { make in
            make.height.equalTo(24)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHovering, isEnabled {
            let isDark = effectiveAppearance.bestMatch(
                from: [.darkAqua, .aqua]
            ) == .darkAqua
            let color = isDark
                ? NSColor.white.withAlphaComponent(0.08)
                : NSColor.black.withAlphaComponent(0.06)
            color.setFill()
            NSBezierPath(
                roundedRect: bounds,
                xRadius: Const.settingsRadius,
                yRadius: Const.settingsRadius
            ).fill()
        }
        super.draw(dirtyRect)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [
                .mouseEnteredAndExited,
                .activeInKeyWindow,
                .inVisibleRect,
            ],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaReference = area
    }

    override func mouseEntered(with _: NSEvent) {
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with _: NSEvent) {
        isHovering = false
        needsDisplay = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
