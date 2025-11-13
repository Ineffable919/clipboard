//
//  AboutView.swift
//  Clipboard
//
//  Created by crown on 2025/11/11.
//

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
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    if let appIcon = NSImage(named: "AppIcon") {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 120, height: 120)
                            .cornerRadius(24)
                            .shadow(
                                color: Color.black.opacity(0.15),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                    } else {
                        Image(systemName: "doc.on.clipboard.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .foregroundColor(.accentColor)
                            .shadow(
                                color: Color.black.opacity(0.1),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    }

                    Text(appName)
                        .font(
                            .system(size: 28, weight: .bold, design: .rounded)
                        )

                    Text("版本 \(appVersion) (\(buildNumber))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 12) {
                    Text("优雅的剪贴板管理工具")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("一款简洁、现代化的 macOS 剪贴板管理应用\n帮助您轻松管理和访问剪贴板历史记录")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                }

                Button(action: {
                    checkForUpdates()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 14))
                        Text("检查更新")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(width: 140)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor)
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .shadow(
                    color: Color.accentColor.opacity(0.3),
                    radius: 8,
                    x: 0,
                    y: 4
                )
                
                Spacer()

                VStack(spacing: 12) {
                    HStack(spacing: 20) {
                        LinkButton(
                            title: "GitHub",
                            icon: "chevron.left.forwardslash.chevron.right"
                        ) {
                            if let url = URL(
                                string:
                                    "https://github.com/Ineffable919/clipboard"
                            ) {
                                NSWorkspace.shared.open(url)
                            }
                        }

                        LinkButton(title: "反馈建议", icon: "envelope") {
                            if let url = URL(
                                string:
                                    "https://github.com/Ineffable919/clipboard/issues"
                            ) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }

                VStack(spacing: 4) {
                    Text(
                        "Copyright © \(currentYear) Crown. All rights reserved."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Text("Made with ❤️ for macOS")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // 检查更新
    private func checkForUpdates() {
        // TODO: 实现检查更新逻辑
        // 可以集成 Sparkle 或其他更新框架
        let alert = NSAlert()
        alert.messageText = "检查更新"
        alert.informativeText = "当前版本：\(appVersion)\n已经是最新版本！"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
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
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isHovered ? Color.accentColor.opacity(0.1) : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isHovered ? Color.accentColor : Color.gray.opacity(0.3),
                        lineWidth: 1
                    )
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
