//
//  WelcomePageTitleView.swift
//  Clipboard
//

import SwiftUI

struct WelcomePageTitleView: View {
    let step: LocalizedStringResource
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(step)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(WelcomeStyle.accent)
                .padding(.bottom, 24)

            Text(title)
                .font(.title.weight(.semibold))
                .tracking(-0.5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 18)

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
