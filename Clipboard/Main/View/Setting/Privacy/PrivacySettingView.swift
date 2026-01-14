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
    @AppStorage(PrefKey.showDuringScreenShare.rawValue) private
    var showDuringScreenShare = true
    @AppStorage(PrefKey.enableLinkPreview.rawValue) private
    var enableLinkPreview = true
    @AppStorage(PrefKey.ignoreSensitiveContent.rawValue) private
    var ignoreSensitiveContent = true
    @AppStorage(PrefKey.ignoreEphemeralContent.rawValue) private
    var ignoreEphemeralContent = true
    @AppStorage(PrefKey.delConfirm.rawValue) private var delConfirm = false
    @State private var hasAccessibilityPermission: Bool = AXIsProcessTrusted()
    @State private var permissionTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(spacing: Const.space16) {
                    VStack(spacing: 0) {
                        PrivacyToggleRow(
                            title: "允许在屏幕共享中显示",
                            subtitle:
                            "关闭后，在屏幕共享、录屏或演示时，窗口不会被捕获，保护您的隐私。",
                            isOn: $showDuringScreenShare,
                        )
                        Divider()
                        PrivacyToggleRow(
                            title: "生成链接预览",
                            subtitle: "开启后对链接生成预览，可能会影响一次性和敏感链接。",
                            isOn: $enableLinkPreview,
                        )
                        Divider()
                        PrivacyToggleRow(
                            title: "忽略机密内容",
                            subtitle: "检测到密码和敏感数据时不保存。",
                            isOn: $ignoreSensitiveContent,
                        )
                        Divider()
                        PrivacyToggleRow(
                            title: "忽略瞬时内容",
                            subtitle: "不要保存其它应用程序生成的临时数据。",
                            isOn: $ignoreEphemeralContent,
                        )
                        Divider()
                        PrivacyToggleRow(
                            title: "删除确认",
                            subtitle: "删除记录时是否弹窗确认。",
                            isOn: $delConfirm,
                        )
                        Divider()
                        AccessibilityPermissionRow(
                            hasPermission: $hasAccessibilityPermission,
                            onOpenSettings: openAccessibilitySettings,
                            onRefresh: refreshPermissionStatus,
                        )
                    }
                    .padding(.horizontal, Const.space16)
                    .settingsStyle()

                    VStack(alignment: .leading, spacing: Const.space4) {
                        Text("忽略应用程序")
                            .font(.headline)
                            .fontWeight(.medium)
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
                                    },
                                )
                            }
                        }
                        .background(
                            Const.headShape
                                .fill(
                                    colorScheme == .light
                                        ? Const.lightBackground
                                        : Const.darkBackground,
                                ),
                        )
                        .overlay(
                            Const.headShape
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1),
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
                        .padding(Const.space4)
                        .background(
                            Const.contentShape
                                .fill(
                                    colorScheme == .light
                                        ? Const.lightToolColor
                                        : Const.darkToolColor,
                                ),
                        )
                        .overlay(
                            Const.contentShape
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1),
                        )
                        .clipShape(Const.contentShape)
                    }
                    .padding(.horizontal, Const.space4)
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: showDuringScreenShare) {
            WindowManager.shared.configureWindowSharing()
        }
        .onAppear {
            refreshPermissionStatus()
            startPermissionTimer()
        }
        .onDisappear {
            stopPermissionTimer()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSWindow.didBecomeKeyNotification,
            ),
        ) { _ in
            startPermissionTimer()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSWindow.didResignKeyNotification,
            ),
        ) { _ in
            stopPermissionTimer()
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
                    path: appPath,
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

    // MARK: - 打开辅助功能设置

    private func openAccessibilitySettings() {
        if let url = URL(
            string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ) {
            NSWorkspace.shared.open(url)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                refreshPermissionStatus()
            }
        }
    }

    // MARK: - 刷新权限状态

    private func refreshPermissionStatus() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    private func startPermissionTimer() {
        stopPermissionTimer()
        permissionTimer = Timer.scheduledTimer(
            withTimeInterval: 2.0,
            repeats: true,
        ) { _ in
            Task { @MainActor in
                refreshPermissionStatus()
            }
        }
    }

    private func stopPermissionTimer() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }
}

// MARK: - 单行开关组件

struct PrivacyToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Const.space12) {
            VStack(alignment: .leading, spacing: Const.space4) {
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
        .padding(.vertical, Const.space12)
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
               withBundleIdentifier: bundleId,
           )
        {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }

        return nil
    }

    // MARK: - fallback图标

    private func getFallbackIcon(for appName: String) -> String {
        if appName.contains("密码") || appName.lowercased().contains("password") {
            "key.fill"
        } else if appName.contains("钥匙串")
            || appName.lowercased().contains("keychain")
        {
            "key.icloud.fill"
        } else {
            "app.fill"
        }
    }
}

// MARK: - 辅助功能权限状态行组件

struct AccessibilityPermissionRow: View {
    @Binding var hasPermission: Bool
    let onOpenSettings: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Const.space12) {
            VStack(alignment: .leading, spacing: Const.space4) {
                Text("辅助功能权限")
                    .font(.callout)
                Text(
                    hasPermission
                        ? "已授权，可以直接粘贴内容到其它应用"
                        : "未授权，仅能复制内容到剪贴板，若已存在，请删除后重新添加",
                )
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if hasPermission {
                    Image(
                        systemName: "checkmark.circle.fill",
                    )
                    .font(.system(size: Const.iconSize18))
                    .foregroundColor(.green)
                }

                if !hasPermission {
                    BorderedButton(title: "去设置", action: onOpenSettings)
                }
            }
        }
        .padding(.vertical, Const.space12)
    }
}

#Preview {
    PrivacySettingView()
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
