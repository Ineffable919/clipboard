//
//  WelcomeWindow.swift
//  Clipboard
//
//  Created by crown on 2026/9/29
//

import AppKit

final class WelcomeWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) {
            return true
        }

        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard modifiers == .command else { return false }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "w":
            performClose(nil)
        case "m":
            performMiniaturize(nil)
        default:
            return false
        }
        return true
    }
}
