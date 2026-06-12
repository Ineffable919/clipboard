//
//  KeyboardShortcuts.swift
//  Clip
//
//  Created by crown on 2025/09/12.
//

import AppKit
import Carbon
import Foundation

enum KeyboardShortcuts {
    static func postCmdVEvent() {
        let source = CGEventSource(stateID: .combinedSessionState)

        let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: true
        )
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: false
        )
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
}
