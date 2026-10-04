//
//  WelcomePreferencesControlsView.swift
//  Clipboard
//

import AppKit
import SwiftUI

#Preview {
    WelcomePreferencesControlsView()
        .frame(width: 360)
        .padding(24)
}

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
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .frame(width: 104, height: 24)
                .background(
                    (colorScheme == .dark ? Color.white : .black).opacity(0.08),
                    in: .rect(cornerRadius: 6)
                )
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
