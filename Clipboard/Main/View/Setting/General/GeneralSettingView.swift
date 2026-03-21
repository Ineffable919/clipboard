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
    @AppStorage(PrefKey.showMenuBarIcon.rawValue) private var showMenuBarIcon = true
    @AppStorage(PrefKey.showDockIcon.rawValue) private var showDockIcon = false
    @AppStorage(PrefKey.soundEnabled.rawValue) private var soundEnabled = true
    @State private var selectedPasteTarget: PasteTargetMode =
        PasteUserDefaults.pasteDirect ? .toApp : .toClipboard
    @AppStorage(PrefKey.pasteOnlyText.rawValue) private var pasteAsPlainText = false
    @AppStorage(PrefKey.removeTailingNewline.rawValue) private var removeTailingNewline = false
    @State private var selectedHistoryTimeUnit: HistoryTimeUnit =
        .init(rawValue: PasteUserDefaults.historyTime)
    @State private var launchAtLoginTimer: Timer?

    private var db: PasteDataStore = .main

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    SettingToggleRow(title: String(localized: .settingGeneralLaunchAtLogin), isOn: $launchAtLogin)
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

                    Divider()

                    SettingToggleRow(title: String(localized: .settingGeneralMenuBarIcon), isOn: $showMenuBarIcon)
                        .onChange(of: showMenuBarIcon) { _, newValue in
                            NotificationCenter.default.post(
                                name: .menuBarIconVisibilityChanged,
                                object: newValue
                            )
                        }

                    Divider()

                    SettingToggleRow(title: String(localized: .settingGeneralDockIcon), isOn: $showDockIcon)
                        .onChange(of: showDockIcon) { _, newValue in
                            NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                        }

                    Divider()

                    SettingToggleRow(title: String(localized: .settingGeneralSound), isOn: $soundEnabled)
                }
                .padding(.horizontal, Const.space16)
                .settingsStyle()

                Text(.settingGeneralPasteItemsSectionTitle)
                    .font(.headline)
                    .bold()

                VStack(alignment: .leading, spacing: 12) {
                    VStack(spacing: 4) {
                        ForEach(PasteTargetMode.allCases, id: \.rawValue) { mode in
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

                    ToggleRow(isEnabled: $pasteAsPlainText, title: String(localized: .settingGeneralPasteAsPlainText))
                    ToggleRow(isEnabled: $removeTailingNewline, title: String(localized: .settingGeneralRemoveTailingNewline))
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
                    HistoryTimeSlider(selectedTimeUnit: $selectedHistoryTimeUnit)
                        .onChange(of: selectedHistoryTimeUnit) { _, newValue in
                            PasteUserDefaults.historyTime = newValue.rawValue
                        }

                    HStack {
                        Spacer()
                        if #available(macOS 26.0, *) {
                            SystemButton(title: String(localized: .settingGeneralClearHistory)) {
                                db.clearAllData()
                            }
                        } else {
                            Button {
                                db.clearAllData()
                            } label: {
                                Text(.settingGeneralClearHistory)
                                    .font(.callout)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(Const.space12)
                .settingsStyle()

                Spacer(minLength: 20)
            }
            .padding(Const.space24)
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
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            startLaunchAtLoginTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
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
        launchAtLoginTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
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
