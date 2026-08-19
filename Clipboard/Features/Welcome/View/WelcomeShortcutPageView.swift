//
//  WelcomeShortcutPageView.swift
//  Clipboard
//

import SwiftUI

struct WelcomeShortcutPageView: View {
    @State private var shortcut = KeyboardShortcut.empty
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        WelcomePageLayout(
            step: .shortcutEyebrow,
            title: .shortcutTitle,
            subtitle: .shortcutSub
        ) {
            VStack(alignment: .leading, spacing: 28) {
                Text(.shortcutGlobalTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(
                        WelcomeStyle.secondaryText(for: colorScheme)
                    )

                ShortcutRecorder(
                    "app_launch",
                    binding: $shortcut,
                    width: 220,
                    minHeight: 32,
                    transparent: true
                )

                WelcomeShortcutGuideView()
            }
        }
    }
}
