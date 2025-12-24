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
                        .cornerRadius(Const.radius)
                        .shadow(
                            color: Color.accentColor.opacity(0.15),
                            radius: Const.radius,
                            x: 0,
                            y: 6,
                        )
                }
                Text(appName)
                    .font(
                        .system(size: 28, weight: .medium, design: .default),
                    )

                Text("\(appVersion) (\(buildNumber))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, Const.space16)

            Button(action: {
                checkForUpdates()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 14))
                    Text("检查更新")
                        .font(.system(size: 14, weight: .regular))
                }
                .frame(width: 120)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: Const.radius)
                        .fill(Color.accentColor),
                )
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .shadow(
                color: Color.accentColor.opacity(0.3),
                radius: Const.radius,
                x: 0,
                y: 4,
            )
            .padding(Const.space32)

            Spacer()

            VStack(spacing: Const.space12) {
                if let updater = AppDelegate.shared?.updaterController.updater {
                    UpdaterSettingsView(updater: updater)
                }
                HStack(spacing: 20) {
                    LinkButton(
                        title: "GitHub",
                        icon: "chevron.left.forwardslash.chevron.right",
                    ) {
                        if let url = URL(
                            string:
                            "https://github.com/Ineffable919/clipboard",
                        ) {
                            NSWorkspace.shared.open(url)
                        }
                    }

                    LinkButton(title: "反馈建议", icon: "envelope") {
                        if let url = URL(
                            string:
                            "https://github.com/Ineffable919/clipboard/issues",
                        ) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                VStack(spacing: 4) {
                    Text(
                        "Copyright © \(currentYear) Crown. All rights reserved.",
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Text("Made with ❤️ for macOS")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, Const.space16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // 检查更新
    private func checkForUpdates() {
        AppDelegate.shared?.updaterController.checkForUpdates(nil)
    }
}

// MARK: - 链接按钮组件

struct LinkButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: Const.space12))
                Text(title)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, Const.space12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Const.radius)
                    .fill(
                        isHovered ? Color.accentColor.opacity(0.1) : Color.clear,
                    ),
            )
            .overlay(
                RoundedRectangle(cornerRadius: Const.radius)
                    .stroke(
                        isHovered ? Color.accentColor : Color.gray.opacity(0.3),
                        lineWidth: 1,
                    ),
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    AboutSettingView()
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
