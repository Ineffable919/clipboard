//
//  WelcomePermissionPageView.swift
//  Clipboard
//

import AppKit
import SwiftUI

struct WelcomePermissionPageView: View {
    let viewModel: WelcomeViewModel
    @State private var launchAtLogin = LaunchAtLoginHelper.shared.isEnabled
    @AppStorage(PrefKey.appearance.rawValue) private var appearanceRaw =
        AppearanceMode.system.rawValue
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        WelcomePageLayout(
            step: .welcomePermissionEyebrow,
            title: .welcomePermissionTitle,
            subtitle: .welcomePermissionSubtitle
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(.settingGeneralLaunchAtLogin)
                            .font(.body.weight(.medium))

                        Text(.welcomePreferencesLaunchAtLoginSubtitle)
                            .font(.footnote)
                            .foregroundStyle(
                                WelcomeStyle.secondaryText(for: colorScheme)
                            )
                    }

                    Spacer()

                    Toggle(
                        String(localized: .settingGeneralLaunchAtLogin),
                        isOn: $launchAtLogin
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                Divider()
                    .overlay(WelcomeStyle.border)
                    .padding(.vertical, 18)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(
                                viewModel.hasAccessibilityPermission
                                    ? WelcomeStyle.accent
                                    : WelcomeStyle.border
                            )
                            .frame(width: 8, height: 8)

                        Text(.settingPrivacyAccessibilityPermissionTitle)
                            .font(.body.weight(.medium))

                        Spacer(minLength: 12)

                        if viewModel.hasAccessibilityPermission {
                            Text(.welcomePermissionGranted)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(WelcomeStyle.accent)
                        } else {
                            Button(.welcomePermissionOpenSettings) {
                                viewModel.openAccessibilitySettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                    }

                    Text(.welcomePermissionAccessibilitySubtitle)
                        .font(.footnote)
                        .foregroundStyle(
                            WelcomeStyle.secondaryText(for: colorScheme)
                        )
                        .padding(.leading, 22)
                }

                Divider()
                    .overlay(WelcomeStyle.border)
                    .padding(.vertical, 18)

                HStack(spacing: 14) {
                    Text(.settingAppearanceModeLabel)
                        .font(.body.weight(.medium))

                    Spacer()

                    Picker(selection: $appearanceRaw) {
                        Label {
                            Text(AppearanceMode.system.title)
                        } icon: {
                            Image(
                                systemName:
                                    "circle.lefthalf.filled.righthalf.striped.horizontal"
                            )
                        }
                        .tag(AppearanceMode.system.rawValue)

                        Label {
                            Text(AppearanceMode.light.title)
                        } icon: {
                            Image(systemName: "sun.max")
                        }
                        .tag(AppearanceMode.light.rawValue)

                        Label {
                            Text(AppearanceMode.dark.title)
                        } icon: {
                            Image(systemName: "moon")
                        }
                        .tag(AppearanceMode.dark.rawValue)
                    } label: {
                        Text(.settingAppearanceModeLabel)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .buttonStyle(.borderless)
                    .frame(width: 128)
                }

                Divider()
                    .overlay(WelcomeStyle.border)
                    .padding(.vertical, 18)

                Text(.welcomePermissionKeyboardPrivacy)
                    .font(.footnote)
                    .foregroundStyle(
                        WelcomeStyle.tertiaryText(for: colorScheme)
                    )
            }
        }
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
        .onChange(of: launchAtLogin) { _, newValue in
            let success = LaunchAtLoginHelper.shared.setEnabled(newValue)
            if success {
                PasteUserDefaults.onStart = newValue
            } else {
                Task { @MainActor in
                    launchAtLogin = LaunchAtLoginHelper.shared.isEnabled
                }
            }
        }
        .onChange(of: appearanceRaw) { _, newValue in
            applyAppearance(AppearanceMode(rawValue: newValue) ?? .system)
        }
    }

    private func applyAppearance(_ mode: AppearanceMode) {
        Task { @MainActor in
            NSApp.appearance =
                switch mode {
                case .system:
                    nil
                case .light:
                    NSAppearance(named: .aqua)
                case .dark:
                    NSAppearance(named: .darkAqua)
                }
        }
    }
}
