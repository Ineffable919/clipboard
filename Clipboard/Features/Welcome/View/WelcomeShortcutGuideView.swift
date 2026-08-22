//
//  WelcomeShortcutGuideView.swift
//  Clipboard
//

import SwiftUI

struct WelcomeShortcutGuideView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(.welcomeShortcutResult)
                .font(.headline)

            previewRow(
                systemImage: "chevron.left.forwardslash.chevron.right",
                tint: WelcomeStyle.secondaryText(for: colorScheme),
                title: "const fetchUser = async (id) => {"
            )

            Divider()
                .overlay(WelcomeStyle.border)

            previewRow(
                systemImage: "link",
                tint: Color(nsColor: .systemTeal),
                title: "https://github.com/Ineffable919/clipboard"
            )

            Divider()
                .overlay(WelcomeStyle.border)

            HStack(spacing: 10) {
                Image(systemName: "text.alignleft")
                    .frame(width: 28, height: 28)
                    .background(
                        WelcomeStyle.subtleSurface(for: colorScheme),
                        in: .rect(cornerRadius: 7)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            WelcomeStyle.secondaryText(for: colorScheme)
                                .opacity(0.5)
                        )
                        .frame(width: 116, height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            WelcomeStyle.secondaryText(for: colorScheme)
                                .opacity(0.3)
                        )
                        .frame(width: 86, height: 4)
                }
            }
        }
    }

    private func previewRow(
        systemImage: String,
        tint: Color,
        title: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(
                    WelcomeStyle.subtleSurface(for: colorScheme),
                    in: .rect(cornerRadius: 7)
                )

            Text(verbatim: title)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
