//
//  WelcomeShortcutGuideView.swift
//  Clipboard
//

import SwiftUI

struct WelcomeShortcutGuideView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 10) {
                Text(.welcomeShortcutStepOpen)
                    .font(.footnote)
                    .foregroundStyle(
                        WelcomeStyle.secondaryText(for: colorScheme)
                    )

                Text(verbatim: "⌘ ⇧ V")
                    .font(.title3)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 52)
                .overlay(WelcomeStyle.border)

            VStack(spacing: 10) {
                Text(.welcomeShortcutStepSearch)
                    .font(.footnote)
                    .foregroundStyle(
                        WelcomeStyle.secondaryText(for: colorScheme)
                    )

                Text(verbatim: "← →")
                    .font(.title3)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 52)
                .overlay(WelcomeStyle.border)

            VStack(spacing: 10) {
                Text(.welcomeShortcutStepPaste)
                    .font(.footnote)
                    .foregroundStyle(
                        WelcomeStyle.secondaryText(for: colorScheme)
                    )

                Text(verbatim: "↵")
                    .font(.title3)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
