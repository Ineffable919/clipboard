//
//  WelcomeIntroductionPageView.swift
//  Clipboard
//

import SwiftUI

struct WelcomeIntroductionPageView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        WelcomePageLayout(
            step: .welcomeIntroductionEyebrow,
            title: .welcomeIntroductionTitle,
            subtitle: .welcomeIntroductionSubtitle
        ) {
            VStack(spacing: 28) {
                WelcomeWorkflowView()

                Label(
                    .welcomePermissionLocalOnly,
                    systemImage: "lock"
                )
                .font(.footnote)
                .foregroundStyle(
                    WelcomeStyle.secondaryText(for: colorScheme)
                )
            }
        }
    }
}
