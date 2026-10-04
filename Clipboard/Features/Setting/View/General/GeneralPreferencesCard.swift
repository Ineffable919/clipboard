//
//  GeneralPreferencesCard.swift
//  Clipboard
//

import AppKit
import Foundation
import SwiftUI

struct GeneralPreferencesCard: View {
    @State private var launchAtLogin = LaunchAtLoginHelper.shared.isEnabled

    @AppStorage(PrefKey.soundEnabled.rawValue)
    private var soundEnabled = true

    @State private var launchAtLoginTimer: Timer?

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
