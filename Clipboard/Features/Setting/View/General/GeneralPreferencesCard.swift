//
//  GeneralPreferencesCard.swift
//  Clipboard
//

import AppKit
import Foundation
import SwiftUI

struct GeneralPreferencesCard: View {
    @State private var launchAtLogin = LaunchAtLoginHelper.shared.isEnabled

    @AppStorage(PrefKey.showMenuBarIcon.rawValue)
    private var showMenuBarIcon = true

    @AppStorage(PrefKey.showDockIcon.rawValue)
    private var showDockIcon = true

    @AppStorage(PrefKey.soundEnabled.rawValue)
    private var soundEnabled = true

    @State private var launchAtLoginTimer: Timer?
    /// 防抖：快速连点会触发多次 .accessory↔.regular 切换并堆积幽灵 Dock 图标，
    /// 用一个可取消的延迟任务把连续切换合并为最终状态的一次应用。
    @State private var dockIconTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SettingToggleRow(
                title: .generalLaunch,
                isOn: $launchAtLogin
            )
            .onChange(of: launchAtLogin) { _, newValue in
                let success = LaunchAtLoginHelper.shared.setEnabled(
                    newValue
                )
                if success {
                    PasteUserDefaults.onStart = newValue
                } else {
                    Task { @MainActor in
                        launchAtLogin =
                            LaunchAtLoginHelper.shared.isEnabled
                    }
                }
            }

            Divider()

            SettingToggleRow(
                title: .generalMenuBarIcon,
                isOn: $showMenuBarIcon
            )
            .onChange(of: showMenuBarIcon) { _, newValue in
                NotificationCenter.default.post(
                    name: .menuBarIconVisibilityChanged,
                    object: newValue
                )
            }

            Divider()

            SettingToggleRow(
                title: .generalDockIcon,
                isOn: $showDockIcon
            )
            .onChange(of: showDockIcon) { _, newValue in
                scheduleDockIconUpdate(visible: newValue)
            }

            Divider()

            SettingToggleRow(
                title: .generalSound,
                isOn: $soundEnabled
            )
        }
        .padding(.horizontal, Const.space16)
        .settingsStyle()
        .onAppear {
            refreshLaunchAtLoginStatus()
            startLaunchAtLoginTimer()
        }
        .onDisappear {
            stopLaunchAtLoginTimer()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSWindow.didBecomeKeyNotification
            )
        ) { _ in
            startLaunchAtLoginTimer()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSWindow.didResignKeyNotification
            )
        ) { _ in
            stopLaunchAtLoginTimer()
        }
    }

    // MARK: - Dock 图标显隐

    private func scheduleDockIconUpdate(visible: Bool) {
        dockIconTask?.cancel()
        dockIconTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            let target: NSApplication.ActivationPolicy =
                visible ? .regular : .accessory
            guard NSApp.activationPolicy() != target else { return }

            NSApp.setActivationPolicy(target)
            if visible {
                NSApp.activate()
            }
        }
    }

    // MARK: - 刷新登录启动状态

    private func refreshLaunchAtLoginStatus() {
        launchAtLogin = LaunchAtLoginHelper.shared.isEnabled
        PasteUserDefaults.onStart = launchAtLogin
    }

    private func startLaunchAtLoginTimer() {
        stopLaunchAtLoginTimer()
        launchAtLoginTimer = Timer.scheduledTimer(
            withTimeInterval: 2.0,
            repeats: true
        ) { _ in
            Task { @MainActor in
                refreshLaunchAtLoginStatus()
            }
        }
    }

    private func stopLaunchAtLoginTimer() {
        launchAtLoginTimer?.invalidate()
        launchAtLoginTimer = nil
    }
}
