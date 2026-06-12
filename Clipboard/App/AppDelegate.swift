//
//  AppDelegate.swift
//  clipboard
//
//  Created by crown on 2025/9/11.
//

import AppKit
import Combine
import QuartzCore
import Sparkle

class AppDelegate: NSObject {
    static var shared: AppDelegate?

    /// Sparkle
    lazy var updaterController: SPUStandardUpdaterController = .init(
        startingUpdater: true,
        updaterDelegate: self,
        userDriverDelegate: self
    )

    private var monitorToken: Any?
}

extension AppDelegate: NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        Self.shared = self

        setupStatusBar()

        applyAppearanceSettings()

        applyDockIconPolicy()

        Task {
            await initClipboardAsync()
        }
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_: Notification) {
        if let token = monitorToken {
            NSEvent.removeMonitor(token)
            monitorToken = nil
        }
        StatusBarController.shared.cleanup()
        AppIconCache.shared.clearCache()
        HotKeyManager.shared.clear()
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        WindowManager.shared.toggleWindow(frame: NSScreen.main?.frame)
        return true
    }

    private func applyDockIconPolicy() {
        let showDockIcon = PasteUserDefaults.showDockIcon
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }

    private func applyAppearanceSettings() {
        let appearanceMode = AppearanceMode(
            rawValue: PasteUserDefaults.appearance
        ) ?? .system

        switch appearanceMode {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func setupStatusBar() {
        StatusBarController.shared.setup(
            onCheckUpdateClick: { [weak self] in
                self?.updaterController.checkForUpdates(nil)
            }
        )
    }
}

extension AppDelegate {
    private func initClipboardAsync() async {
        PasteBoard.main.startListening()

        PasteDataStore.main.setup()

        initLocalEvent()

        HotKeyManager.shared.initialize()

        syncLaunchAtLoginStatus()

        updaterController.updater.checkForUpdatesInBackground()
    }

    private func syncLaunchAtLoginStatus() {
        let userDefaultsValue = PasteUserDefaults.onStart
        let actualValue = LaunchAtLoginHelper.shared.isEnabled
        if userDefaultsValue != actualValue {
            LaunchAtLoginHelper.shared.setEnabled(userDefaultsValue)
        }
    }
}

extension AppDelegate {
    private func initLocalEvent() {
        monitorToken = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            event in
            if event.modifierFlags.contains(.command) {
                let modifiers = event.charactersIgnoringModifiers
                if modifiers == "," || modifiers == "，" {
                    SettingWindowController.shared.toggleWindow(page: .general)
                    return nil
                }
                if modifiers == "q" || modifiers == "Q" {
                    NSApplication.shared.terminate(nil)
                    return nil
                }
                if modifiers == "t" || modifiers == "T" {
                    EditWindowController.shared.openNewWindow()
                    return nil
                }
            }
            return event
        }
    }
}

// MARK: - SPUUpdaterDelegate

extension AppDelegate: SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    nonisolated func updater(_: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        Task { @MainActor in
            UpdateManager.shared.setUpdateAvailable(version: version)
        }
    }

    nonisolated func updaterDidNotFindUpdate(_: SPUUpdater) {
        Task { @MainActor in
            UpdateManager.shared.clearUpdate()
        }
    }

    nonisolated func updater(
        _: SPUUpdater,
        userDidMake choice: SPUUserUpdateChoice,
        forUpdate _: SUAppcastItem,
        state _: SPUUserUpdateState
    ) {
        if choice == .skip {
            Task { @MainActor in
                UpdateManager.shared.clearUpdate()
            }
        }
    }

    var supportsGentleScheduledUpdateReminders: Bool {
        true
    }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ willHandle: Bool,
        forUpdate update: SUAppcastItem,
        state _: SPUUserUpdateState
    ) {
        guard !willHandle else { return }
        log.info("发现更新：\(update.displayVersionString)")
        UpdateManager.shared.setUpdateAvailable(version: update.displayVersionString)
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate _: SUAppcastItem) {
        updaterController.checkForUpdates(nil)
    }

    func standardUserDriverWillFinishUpdateSession() {
        UpdateManager.shared.clearUpdate()
    }
}

// MARK: - Notification.Name

extension Notification.Name {
    static let menuBarIconVisibilityChanged = Notification.Name("menuBarIconVisibilityChanged")
}
