//
//  WelcomePreferencesControlsView.swift
//  Clipboard
//

import AppKit
import SwiftUI

struct WelcomePreferencesControlsView: View {
    @State private var launchAtLogin = LaunchAtLoginHelper.shared.isEnabled
    @AppStorage(PrefKey.appearance.rawValue) private var appearanceRaw =
        AppearanceMode.system.rawValue
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 20) {
            HStack(spacing: 6) {
                Text(.generalLaunch)
                    .font(.footnote)
                    .foregroundStyle(
                        WelcomeStyle.secondaryText(for: colorScheme)
                    )

                Toggle(
                    String(localized: .generalLaunch),
                    isOn: $launchAtLogin
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            HStack(spacing: 6) {
                Text(.appearanceModeLabel)
                    .font(.footnote)
                    .foregroundStyle(
                        WelcomeStyle.secondaryText(for: colorScheme)
                    )

                Menu {
                    ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                        Button {
                            appearanceRaw = mode.rawValue
                        } label: {
                            if mode == currentAppearance {
                                Label(mode.title, systemImage: "checkmark")
                            } else {
                                Text(mode.title)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(currentAppearance.title)
                            .font(.footnote)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(
                                WelcomeStyle.primaryText(for: colorScheme)
                            )

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(
                                WelcomeStyle.secondaryText(for: colorScheme)
                            )
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        WelcomeStyle.subtleSurface(for: colorScheme),
                        in: .rect(cornerRadius: 7)
                    )
                    .contentShape(.rect)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .tint(WelcomeStyle.primaryText(for: colorScheme))
                .frame(width: 88, height: 28)
            }
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

    private var currentAppearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
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
