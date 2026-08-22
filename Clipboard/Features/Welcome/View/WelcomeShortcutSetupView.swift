//
//  WelcomeShortcutSetupView.swift
//  Clipboard
//

import SwiftUI

struct WelcomeShortcutSetupView: View {
    @Binding var shortcut: KeyboardShortcut
    let onRestoreDefault: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(.shortcutGlobalTitle)
                    .font(.headline)

                Text(.welcomeShortcutCurrent)
                    .font(.footnote)
                    .foregroundStyle(
                        WelcomeStyle.secondaryText(for: colorScheme)
                    )

                ShortcutRecorder(
                    "app_launch",
                    binding: $shortcut,
                    width: 148,
                    minHeight: 32
                )

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(.shortcutGlobalSub)
                        .font(.caption)
                        .foregroundStyle(
                            WelcomeStyle.secondaryText(for: colorScheme)
                        )

                    Spacer(minLength: 0)

                    Button(.welcomeShortcutRestoreDefault) {
                        onRestoreDefault()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(WelcomeStyle.accent)
                }
            }
            .frame(width: 236, alignment: .leading)

            Divider()
                .overlay(WelcomeStyle.border)
                .frame(height: 132)

            WelcomeShortcutGuideView()
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(WelcomeStyle.surface(for: colorScheme))
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(WelcomeStyle.border, lineWidth: 1)
        }
        .shadow(
            color: WelcomeStyle.panelShadow(for: colorScheme),
            radius: 10,
            y: 5
        )
    }
}
