//
//  WelcomeIntroductionCopyView.swift
//  Clipboard
//

import SwiftUI

struct WelcomeIntroductionCopyView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WelcomeHeaderView()

            Text(.introTitle)
                .font(.title2.weight(.semibold))
                .tracking(-0.4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Text(.introSub)
                .font(.body)
                .foregroundStyle(
                    WelcomeStyle.secondaryText(for: colorScheme)
                )
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Label(.permissionLocalOnly, systemImage: "lock")
                .font(.footnote)
                .foregroundStyle(
                    WelcomeStyle.secondaryText(for: colorScheme)
                )
                .padding(.top, 40)
        }
    }
}
