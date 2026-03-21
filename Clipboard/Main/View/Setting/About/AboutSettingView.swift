//
//  AboutSettingView.swift
//  Clipboard
//
//  Created by crown on 2025/11/11.
//

import Sparkle
import SwiftUI

struct AboutSettingView: View {
    @Environment(\.colorScheme) var colorScheme

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Clipboard"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "1"
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    var body: some View {
        VStack {
            VStack(spacing: 8) {
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 120, height: 120)
                        .clipShape(.rect(cornerRadius: Const.radius))
                        .shadow(
                            color: Color.accentColor.opacity(0.15),
                            radius: Const.radius,
                            x: 0,
                            y: 6
                        )
                        .onDrag {
                            if let appURL = Bundle.main.bundleURL as NSURL? {
                                return NSItemProvider(object: appURL)
                            }
                            return NSItemProvider()
                        }
                        .onHover { isHovered in
                            if isHovered {
                                NSCursor.openHand.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                        }
                }
                Text(appName)
                    .font(
                        .system(size: 28, weight: .medium, design: .default)
                    )

                Text("\(appVersion) (\(buildNumber))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, Const.space16)

            Button(action: {
                checkForUpdates()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 14))
                    Text(.settingAboutCheckForUpdates)
                        .font(.system(size: 14, weight: .regular))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, Const.space16)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: Const.radius)
                        .fill(Color.accentColor)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .shadow(
                color: Color.accentColor.opacity(0.3),
                radius: Const.radius,
                x: 0,
                y: 4
            )
            .padding(Const.space32)

            Spacer()

            VStack(spacing: Const.space12) {
                if let updater = AppDelegate.shared?.updaterController.updater {
                    UpdaterSettingsView(updater: updater)
                }
                HStack(spacing: 20) {
                    if let github = URL(string: "https://github.com/Ineffable919/clipboard") {
                        Link(String(localized: .settingAboutGithub), destination: github)
                    }
                    if let issues = URL(string: "https://github.com/Ineffable919/clipboard/issues") {
                        Link(String(localized: .settingAboutFeedback), destination: issues)
                    }
                }
                VStack(spacing: Const.space4) {
                    Text(.settingAboutMadeForMac)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(
                        String.localizedStringWithFormat(
                            String(
                                localized: "settingAboutCopyrightFormat",
                                defaultValue: "Copyright © %lld Crown. All rights reserved.",
                                table: "Localizable"
                            ),
                            currentYear
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, Const.space16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 检查更新
    private func checkForUpdates() {
        AppDelegate.shared?.updaterController.checkForUpdates(nil)
    }
}

#Preview {
    AboutSettingView()
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
