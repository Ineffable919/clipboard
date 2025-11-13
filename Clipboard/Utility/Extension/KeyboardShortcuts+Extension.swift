//
//  KeyboardShortcuts+Extension.swift
//  Clip
//
//  Created by crown on 2025/09/12.
//

import AppKit
import Carbon
import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleClipKey = Self(
        "shortcurs",
        default: Shortcut(.v, modifiers: [.command, .shift])
    )
}

extension KeyboardShortcuts {
    static func postCmdVEvent() {
        let hasPermission = AXIsProcessTrusted()

        if !hasPermission {
            log.debug(
                "Accessibility permission not granted, cannot send keyboard events"
            )
            DispatchQueue.main.async {
                requestAccessibilityPermission()
            }
            return
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        let cgEvent = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: true
        )
        cgEvent?.flags = .maskCommand
        cgEvent?.post(tap: .cghidEventTap)
    }

    private static func requestAccessibilityPermission() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = """
            Clip 需要访问辅助功能权限才能直接粘贴到其它应用
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "设置")
        alert.addButton(withTitle: "稍后设置，复制到剪切板")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            ) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
