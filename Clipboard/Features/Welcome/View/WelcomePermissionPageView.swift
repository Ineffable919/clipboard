//
//  WelcomePermissionPageView.swift
//  Clipboard
//

import AppKit
import SwiftUI

struct WelcomePermissionPageView: View {
    let viewModel: WelcomeViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 42) {
            VStack(alignment: .leading, spacing: 22) {
                WelcomePageTitleView(
                    title: .permissionTitle,
                    subtitle: .permissionSub
                )

                Label(.permissionKeyboardPrivacy, systemImage: "lock")
                    .font(.footnote)
                    .foregroundStyle(
                        WelcomeStyle.secondaryText(for: colorScheme)
                    )
            }
            .frame(width: 270, alignment: .leading)

            WelcomePermissionCardView(viewModel: viewModel)
                .frame(width: 312)
        }
        .padding(.horizontal, WelcomeStyle.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.refreshAccessibilityPermission()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            viewModel.refreshAccessibilityPermission()
        }
    }
}
