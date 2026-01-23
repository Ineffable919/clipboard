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
        let cgEvent = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: true
        )
        cgEvent?.flags = .maskCommand
        cgEvent?.post(tap: .cghidEventTap)
    }
}
