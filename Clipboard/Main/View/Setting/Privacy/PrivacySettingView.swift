//
//  PrivacySettingView.swift
//  Clipboard
//
//  Created by crown on 2025/10/28.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - 隐私设置视图

struct PrivacySettingView: View {
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedApp: String? = nil
    @State private var ignoredApps: [IgnoredAppInfo] = PasteUserDefaults
        .ignoredApps
    @State private var showDuringScreenShare: Bool = PasteUserDefaults
        .showDuringScreenShare
    @State private var enableLinkPreview: Bool = PasteUserDefaults
        .enableLinkPreview
    @State private var ignoreSensitiveContent: Bool = PasteUserDefaults
        .ignoreSensitiveContent
    @State private var ignoreEphemeralContent: Bool = PasteUserDefaults
        .ignoreEphemeralContent
    @State private var delConfirm: Bool = PasteUserDefaults.delConfirm

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 0) {
                        PrivacyToggleRow(
                            title: "允许在屏幕共享中显示",
                            subtitle:
                                "关闭后，在屏幕共享、录屏或演示时，Clip 窗口不会被捕获，保护您的隐私。",
                            isOn: $showDuringScreenShare
                        )
                        Divider()
                        PrivacyToggleRow(
                            title: "生成链接预览",
                            subtitle: "开启后对链接生成预览，可能会影响一次性和敏感链接。",
                            isOn: $enableLinkPreview
                        )
                        Divider()
                        PrivacyToggleRow(
                            title: "忽略机密内容",
                            subtitle: "检测到密码和敏感数据时不保存。",
                            isOn: $ignoreSensitiveContent
                        )
                        Divider()
                        PrivacyToggleRow(
                            title: "忽略瞬时内容",
                            subtitle: "不要保存其它应用程序生成的临时数据。",
                            isOn: $ignoreEphemeralContent
                        )
                        Divider()
                        PrivacyToggleRow(
                            title: "删除确认",
                            subtitle: "删除记录时是否弹窗确认。",
                            isOn: $delConfirm
                        )
                    }
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: Const.radius)
                            .fill(
                                colorScheme == .light
                                    ? Const.lightBackground
                                    : Const.darkBackground
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Const.radius)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("忽略应用程序")
                            .font(.body)
                        Text("不要保存从以下应用程序复制的内容。")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 0) {
                        VStack(spacing: 0) {
                            ForEach(ignoredApps) { app in
                                IgnoredAppRow(
                                    appInfo: app,
                                    isSelected: selectedApp == app.id,
                                    onSelect: {
                                        if selectedApp == app.id {
                                            selectedApp = nil
                                        } else {
                                            selectedApp = app.id
                                        }
                                    }
                                )
                            }
                        }
                        .background(
                            Const.headShape
                                .fill(
                                    colorScheme == .light
                                        ? Const.lightBackground
                                        : Const.darkBackground
                                )
                        )
                        .overlay(
                            Const.headShape
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .clipShape(Const.headShape)

                        HStack(spacing: 6) {
                            Button(action: addApp) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14))
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.borderless)

                            Divider()

                            Button(action: removeSelectedApp) {
                                Image(systemName: "minus")
                                    .font(.system(size: 14))
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.borderless)
                            .disabled(selectedApp == nil)

                            Spacer()
                        }
                        .padding(4)
                        .background(
                            Const.contentShape
                                .fill(
                                    colorScheme == .light
                                        ? Const.lightToolColor
                                        : Const.darkToolColor
                                )
                        )
                        .overlay(
                            Const.contentShape
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .clipShape(Const.contentShape)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: showDuringScreenShare) {
            PasteUserDefaults.showDuringScreenShare = showDuringScreenShare
            ClipMainWindowController.shared.configureWindowSharing()
        }
        .onChange(of: enableLinkPreview) {
            PasteUserDefaults.enableLinkPreview = enableLinkPreview
        }
        .onChange(of: ignoreSensitiveContent) {
            PasteUserDefaults.ignoreSensitiveContent = ignoreSensitiveContent
        }
        .onChange(of: ignoreEphemeralContent) {
            PasteUserDefaults.ignoreEphemeralContent = ignoreEphemeralContent
        }
        .onChange(of: delConfirm) {
            PasteUserDefaults.delConfirm = delConfirm
        }
    }

    // MARK: - 添加应用

    private func addApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            let appName = url.deletingPathExtension().lastPathComponent
            let appPath = url.path

            var bundleIdentifier: String? = nil
            if let bundle = Bundle(url: url) {
                bundleIdentifier = bundle.bundleIdentifier
            }

            let exists = ignoredApps.contains { app in
                app.path == appPath
                    || (bundleIdentifier != nil
                        && app.bundleIdentifier == bundleIdentifier)
            }

            if !exists {
                let appInfo = IgnoredAppInfo(
                    name: appName,
                    bundleIdentifier: bundleIdentifier,
                    path: appPath
                )
                ignoredApps.insert(appInfo, at: 0)
                PasteUserDefaults.ignoredApps = ignoredApps
            }
        }
    }

    // MARK: - 删除选中的应用

    private func removeSelectedApp() {
        if let selected = selectedApp {
            ignoredApps.removeAll { $0.id == selected }
            selectedApp = nil
            PasteUserDefaults.ignoredApps = ignoredApps
        }
    }
}

// MARK: - 单行开关组件

struct PrivacyToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.vertical, 12)
    }
}

// MARK: - 忽略应用单行组件

struct IgnoredAppRow: View {
    let appInfo: IgnoredAppInfo
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if let appIcon = getAppIcon(for: appInfo) {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: getFallbackIcon(for: appInfo.name))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .foregroundColor(.secondary)
            }

            Text(appInfo.name)
                .font(.system(size: 14))

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }

    // MARK: - 获取应用图标

    private func getAppIcon(for appInfo: IgnoredAppInfo) -> NSImage? {
        if FileManager.default.fileExists(atPath: appInfo.path) {
            let icon = NSWorkspace.shared.icon(forFile: appInfo.path)
            if icon.size.width > 0 {
                return icon
            }
        }

        if let bundleId = appInfo.bundleIdentifier,
            let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleId
            )
        {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }

        return nil
    }

    // MARK: - fallback图标

    private func getFallbackIcon(for appName: String) -> String {
        if appName.contains("密码") || appName.lowercased().contains("password") {
            return "key.fill"
        } else if appName.contains("钥匙串")
            || appName.lowercased().contains("keychain")
        {
            return "key.icloud.fill"
        } else {
            return "app.fill"
        }
    }
}

#Preview {
    PrivacySettingView()
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
