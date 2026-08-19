//
//  WelcomeHeaderView.swift
//  Clipboard
//

import SwiftUI

struct WelcomeHeaderView: View {
    let showsSkip: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Text(verbatim: "Clip")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            WelcomeStyle.accent,
                            Color(nsColor: .systemCyan),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Spacer()

            if showsSkip {
                Button(.skip) {
                    WelcomeWindowController.shared.skipWelcome()
                }
                .buttonStyle(.plain)
                .font(.body)
                .foregroundStyle(
                    WelcomeStyle.secondaryText(for: colorScheme)
                )
            }
        }
        .frame(height: 20)
        .padding(.top, 48)
        .padding(.horizontal, WelcomeStyle.horizontalPadding)
    }
}
