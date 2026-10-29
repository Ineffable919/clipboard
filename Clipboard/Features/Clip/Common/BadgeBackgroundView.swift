//
//  BadgeBackgroundView.swift
//  Clipboard
//

import AppKit

final class BadgeBackgroundView: NSView {
    var isCapsule = false

    var dynamicBackgroundColor: NSColor = .clear {
        didSet { needsDisplay = true }
    }

    var backgroundAlpha: CGFloat = 1.0 {
        didSet { needsDisplay = true }
    }

    override var wantsUpdateLayer: Bool {
        true
    }

    override func layout() {
        super.layout()
        if isCapsule {
            layer?.cornerRadius = bounds.height / 2
        }
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = dynamicBackgroundColor
                .withAlphaComponent(backgroundAlpha).cgColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
