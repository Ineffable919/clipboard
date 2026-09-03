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
        VStack(spacing: 0) {
            HStack {
                Text(.generalLaunch)
                    .font(.footnote)
                    .foregroundStyle(
                        WelcomeStyle.secondaryText(for: colorScheme)
                    )

                Spacer()

                Toggle(
                    String(localized: .generalLaunch),
                    isOn: $launchAtLogin
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            .frame(height: 48)

            Divider()
                .overlay(WelcomeStyle.border)

            HStack {
                Text(.appearanceModeLabel)
                    .font(.footnote)
                    .foregroundStyle(
                        WelcomeStyle.secondaryText(for: colorScheme)
                    )

                Spacer()

                Picker(
                    String(localized: .appearanceModeLabel),
                    selection: $appearanceRaw
                ) {
                    ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                        Text(mode.title)
                            .tag(mode.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 104)
            }
            .frame(height: 48)
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
