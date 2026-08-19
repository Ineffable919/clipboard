//
//  WelcomeIntroductionPageView.swift
//  Clipboard
//

import SwiftUI

struct WelcomeIntroductionPageView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        WelcomePageLayout(
            step: .introEyebrow,
            title: .introTitle,
            subtitle: .introSub
        ) {
            VStack(spacing: 28) {
                WelcomeWorkflowView()

                Label(
                    .permissionLocalOnly,
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
