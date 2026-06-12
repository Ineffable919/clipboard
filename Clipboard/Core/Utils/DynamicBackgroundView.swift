//
//  DynamicBackgroundView.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit

final class DynamicBackgroundView: NSView {
    var dynamicBackgroundColor: NSColor = .clear {
        didSet { needsDisplay = true }
    }

    override var wantsUpdateLayer: Bool {
        true
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = dynamicBackgroundColor.cgColor

            let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            layer?.borderColor = isDark
                ? NSColor.secondaryLabelColor.withAlphaComponent(0.05).cgColor
                : NSColor.black.withAlphaComponent(0.06).cgColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
