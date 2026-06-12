//
//  SettingWindow.swift
//  Clipboard
//
//  Created by crown on 2026/4/18.
//

import AppKit

final class SettingWindow: NSWindow {
    var onCommandW: (() -> Void)?
    var onCommandM: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "w"
        {
            onCommandW?()
            return
        }

        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "m"
        {
            onCommandM?()
            return
        }

        super.keyDown(with: event)
    }
}
