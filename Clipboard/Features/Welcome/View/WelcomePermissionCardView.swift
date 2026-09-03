//
//  WelcomePermissionCardView.swift
//  Clipboard
//

import SwiftUI

struct WelcomePermissionCardView: View {
    let viewModel: WelcomeViewModel

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "accessibility")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(WelcomeStyle.accent, in: .rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(.privacyAccessPermissionTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(
                        viewModel.hasAccessibilityPermission
                            ? .permissionGranted
                            : .welcomePermissionNotEnabled
                    )
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(
                        viewModel.hasAccessibilityPermission
                            ? WelcomeStyle.accent
                            : WelcomeStyle.secondaryText(for: colorScheme)
                    )
                }

                if viewModel.hasAccessibilityPermission {
                    Spacer(minLength: 8)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(WelcomeStyle.accent)
                }
            }
            .padding(.bottom, 16)

            Divider()
                .overlay(WelcomeStyle.border)

            HStack(alignment: .center, spacing: 12) {
                Text(.permissionAccessSub)
                    .font(.footnote)
                    .foregroundStyle(
                        WelcomeStyle.secondaryText(for: colorScheme)
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !viewModel.hasAccessibilityPermission {
                    Button(.permissionOpenSettings) {
                        viewModel.openAccessibilitySettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(width: 104)
                    .tint(WelcomeStyle.accent)
                }
            }
            .frame(height: 48)

            Divider()
                .overlay(WelcomeStyle.border)

            WelcomePreferencesControlsView()
        }
        .padding(18)
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
