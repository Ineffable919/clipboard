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
            step: .welcomeShortcutEyebrow,
            title: .welcomeShortcutTitle,
            subtitle: .welcomeShortcutSubtitle
        ) {
            VStack(alignment: .leading, spacing: 28) {
                Text(.welcomeShortcutGlobalTitle)
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
