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
        layer?.backgroundColor = dynamicBackgroundColor.cgColor
    }
}
