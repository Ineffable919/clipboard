//
//  WelcomePageTitleView.swift
//  Clipboard
//

import SwiftUI

struct WelcomePageTitleView: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 32, weight: .semibold))
                .tracking(-0.8)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(
                    WelcomeStyle.secondaryText(for: colorScheme)
                )
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
