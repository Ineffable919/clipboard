//
//  GeneralSettingView.swift
//  Clipboard
//
//  Created by crown on 2025/10/28.
//

import Foundation
import SwiftUI

// MARK: - 通用设置视图

struct GeneralSettingView: View {
    @State private var launchAtLogin: Bool = LaunchAtLoginHelper.shared.isEnabled

    @AppStorage(PrefKey.showMenuBarIcon.rawValue)
    private var showMenuBarIcon = true

    @AppStorage(PrefKey.showDockIcon.rawValue)
    private var showDockIcon = true

    @AppStorage(PrefKey.soundEnabled.rawValue)
    private var soundEnabled = true

    @State private var selectedPasteTarget: PasteTargetMode =
        PasteUserDefaults.pasteDirect ? .toApp : .toClipboard

    @AppStorage(PrefKey.pasteOnlyText.rawValue)
    private var pasteAsPlainText = false

    @AppStorage(PrefKey.removeTailingNewline.rawValue)
    private var removeTailingNewline = false

    @State private var selectedHistoryTimeUnit: HistoryTimeUnit =
        .init(rawValue: PasteUserDefaults.historyTime)

    @State private var launchAtLoginTimer: Timer?
    // 防抖：快速连点会触发多次 .accessory↔.regular 切换并堆积幽灵 Dock 图标，
    // 用一个可取消的延迟任务把连续切换合并为最终状态的一次应用。
    @State private var dockIconTask: Task<Void, Never>?

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    SettingToggleRow(
                        title: .settingGeneralLaunchAtLogin,
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
                        title: .settingGeneralMenuBarIcon,
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
                        title: .settingGeneralDockIcon,
                        isOn: $showDockIcon
                    )
                    .onChange(of: showDockIcon) { _, newValue in
                        scheduleDockIconUpdate(visible: newValue)
                    }

                    Divider()

                    SettingToggleRow(
                        title: .settingGeneralSound,
                        isOn: $soundEnabled
                    )
                }
                .padding(.horizontal, Const.space16)
                .settingsStyle()

                Text(.settingGeneralPasteItemsSectionTitle)
                    .font(.headline)
                    .bold()

                VStack(alignment: .leading, spacing: Const.space12) {
                    VStack(spacing: Const.space4) {
                        ForEach(PasteTargetMode.allCases, id: \.rawValue) {
                            mode in
                            PasteTargetModeRow(
                                mode: mode,
                                isSelected: selectedPasteTarget == mode,
                                onSelect: { selectedPasteTarget = mode }
                            )
                        }
                    }
                    .onChange(of: selectedPasteTarget) { _, newValue in
                        PasteUserDefaults.pasteDirect = (newValue == .toApp)
                    }

                    Divider()

                    ToggleRow(
                        isEnabled: $pasteAsPlainText,
                        title: String(
                            localized: .settingGeneralPasteAsPlainText
                        )
                    )
                    ToggleRow(
                        isEnabled: $removeTailingNewline,
                        title: String(
                            localized: .settingGeneralRemoveTailingNewline
                        )
                    )
                }
                .padding(Const.space8)
                .settingsStyle()

                HStack {
                    Text(.settingGeneralHistorySectionTitle)
                        .font(.headline)
                        .bold()
                    Image(systemName: "exclamationmark.circle")
                        .help(Text(.settingGeneralHistoryCleanupHint))
                }

                VStack(alignment: .leading, spacing: Const.space8) {
                    HistoryTimeSlider(
                        selectedTimeUnit: $selectedHistoryTimeUnit
                    )
                    .onChange(of: selectedHistoryTimeUnit) { _, newValue in
                        PasteUserDefaults.historyTime = newValue.rawValue
                    }

                    HStack {
                        Spacer()
                        SystemButton(
                            title: String(
                                localized: .settingGeneralClearHistory
                            ),
                            action: PasteDataStore.main.clearAllData
                        )
                    }
                }
                .padding(Const.space12)
                .settingsStyle()

                Spacer(minLength: 20)
            }
            .padding([.horizontal, .bottom], Const.space24)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                NSApp.activate(ignoringOtherApps: true)
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

#Preview {
    GeneralSettingView()
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
