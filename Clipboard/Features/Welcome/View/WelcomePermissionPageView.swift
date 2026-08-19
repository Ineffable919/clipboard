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
            step: .permissionEyebrow,
            title: .permissionTitle,
            subtitle: .permissionSub
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(.generalLaunch)
                            .font(.body.weight(.medium))

                        Text(.preferencesLaunchSub)
                            .font(.footnote)
                            .foregroundStyle(
                                WelcomeStyle.secondaryText(for: colorScheme)
                            )
                    }

                    Spacer()

                    Toggle(
                        String(localized: .generalLaunch),
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
                        Text(.privacyAccessPermissionTitle)
                            .font(.body.weight(.medium))

                        Spacer(minLength: 12)

                        if viewModel.hasAccessibilityPermission {
                            Text(.permissionGranted)
                                .font(.body.weight(.medium))
                                .foregroundStyle(WelcomeStyle.accent)
                                .frame(width: 128, alignment: .trailing)
                        } else {
                            Button(.permissionOpenSettings) {
                                viewModel.openAccessibilitySettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .frame(width: 128, alignment: .trailing)
                        }
                    }

                    Text(.permissionAccessSub)
                        .font(.footnote)
                        .foregroundStyle(
                            WelcomeStyle.secondaryText(for: colorScheme)
                        )
                }

                Divider()
                    .overlay(WelcomeStyle.border)
                    .padding(.vertical, 18)

                HStack(spacing: 14) {
                    Text(.appearanceModeLabel)
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
                        Text(.appearanceModeLabel)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .buttonStyle(.borderless)
                    .frame(width: 128, alignment: .trailing)
                    .offset(x: 6)
                }

                Divider()
                    .overlay(WelcomeStyle.border)
                    .padding(.vertical, 18)

                Text(.permissionKeyboardPrivacy)
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
