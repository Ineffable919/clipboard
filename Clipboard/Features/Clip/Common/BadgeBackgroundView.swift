//
//  BadgeBackgroundView.swift
//  Clipboard
//

import AppKit

final class BadgeBackgroundView: NSView {
    var dynamicBackgroundColor: NSColor = .clear {
        didSet { needsDisplay = true }
    }

    var backgroundAlpha: CGFloat = 1.0 {
        didSet { needsDisplay = true }
    }

    override var wantsUpdateLayer: Bool { true }

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
