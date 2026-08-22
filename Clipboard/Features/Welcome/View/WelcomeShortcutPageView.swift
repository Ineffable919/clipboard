//
//  WelcomeShortcutPageView.swift
//  Clipboard
//

import AppKit
import SwiftUI

struct WelcomeShortcutPageView: View {
    @State private var shortcut = KeyboardShortcut.empty

    var body: some View {
        WelcomePageLayout(
            title: .shortcutTitle,
            subtitle: .shortcutSub
        ) {
            WelcomeShortcutSetupView(
                shortcut: $shortcut,
                onRestoreDefault: restoreDefaultShortcut
            )
        }
    }

    private func restoreDefaultShortcut() {
        let defaultShortcut = KeyboardShortcut(
            modifiersRawValue: NSEvent.ModifierFlags([.command, .shift])
                .rawValue,
            keyCode: KeyCode.v,
            displayKey: "V"
        )

        let restoredShortcut =
            if HotKeyManager.shared.getHotKey(key: "app_launch") == nil {
                HotKeyManager.shared.addHotKey(
                    key: "app_launch",
                    shortcut: defaultShortcut,
                    isGlobal: true
                )
            } else {
                HotKeyManager.shared.updateHotKey(
                    key: "app_launch",
                    shortcut: defaultShortcut,
                    isEnabled: true
                )
            }

        guard let restoredShortcut else { return }
        shortcut = restoredShortcut.shortcut
    }
}
