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

        if super.performKeyEquivalent(with: event) {
            return true
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.command),
              !modifiers.contains(.option),
              !modifiers.contains(.control)
        else { return false }

        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let isShift = modifiers.contains(.shift)

        let action: Selector? = switch key {
        case "c": #selector(NSText.copy(_:))
        case "v": #selector(NSText.paste(_:))
        case "x": #selector(NSText.cut(_:))
        case "a": #selector(NSResponder.selectAll(_:))
        case "z": isShift ? Selector(("redo:")) : Selector(("undo:"))
        default: nil
        }

        guard let action else { return false }
        return NSApp.sendAction(action, to: nil, from: nil)
    }
}
