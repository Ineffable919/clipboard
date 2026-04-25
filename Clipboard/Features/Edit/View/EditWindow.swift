//
//  EditWindow.swift
//  Clipboard
//
//  Created by crown on 2026/4/25.
//

import AppKit

final class EditWindow: NSWindow {
    var onKeyEquivalent: ((NSEvent) -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let handler = onKeyEquivalent, handler(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
