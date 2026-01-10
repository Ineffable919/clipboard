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

    // Sparkle
    lazy var updaterController: SPUStandardUpdaterController = .init(
        startingUpdater: true,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    private var menuBarItem: NSStatusItem?

    private lazy var rMenu: NSMenu = {
        let menu = NSMenu(title: "设置")

        let item1 = NSMenuItem(
            title: "偏好设置",
            action: #selector(settingsAction),
            keyEquivalent: ","
        )
        item1.image = NSImage(
            systemSymbolName: "gearshape",
            accessibilityDescription: nil
        )
        menu.addItem(item1)

        let item2 = NSMenuItem(
            title: "检查更新",
            action: #selector(checkUpdate),
            keyEquivalent: ""
        )
        item2.image = NSImage(
            systemSymbolName: "arrow.clockwise",
            accessibilityDescription: nil
        )
        menu.addItem(item2)

        menu.addItem(NSMenuItem.separator())

        let pauseItem = NSMenuItem(
            title: "暂停",
            action: nil,
            keyEquivalent: ""
        )
        pauseItem.image = NSImage(
            systemSymbolName: "pause.circle",
            accessibilityDescription: nil
        )
        pauseItem.submenu = createPauseSubmenu()
        menu.addItem(pauseItem)

        let item3 = NSMenuItem(
            title: "退出",
            action: #selector(NSApplication.shared.terminate),
            keyEquivalent: "q"
        )
        menu.addItem(item3)

        menu.delegate = self

        return menu
    }()

    private func createPauseSubmenu() -> NSMenu {
        let submenu = NSMenu()
        let isPaused = PasteBoard.main.isPaused

        if isPaused {
            let resumeItem = NSMenuItem(
                title: "恢复",
                action: #selector(resumePasteboard),
                keyEquivalent: ""
            )
            resumeItem.image = NSImage(
                systemSymbolName: "play.circle",
                accessibilityDescription: nil
            )
            submenu.addItem(resumeItem)
            submenu.addItem(NSMenuItem.separator())
        } else {
            let pauseIndefinite = NSMenuItem(
                title: "暂停",
                action: #selector(pauseIndefinitely),
                keyEquivalent: ""
            )
            pauseIndefinite.image = NSImage(
                systemSymbolName: "pause.circle",
                accessibilityDescription: nil
            )
            submenu.addItem(pauseIndefinite)

            submenu.addItem(NSMenuItem.separator())
        }

        let pause15 = NSMenuItem(
            title: "暂停 15 分钟",
            action: #selector(pause15Minutes),
            keyEquivalent: ""
        )
        pause15.image = NSImage(
            systemSymbolName: "15.circle",
            accessibilityDescription: nil
        )
        submenu.addItem(pause15)

        let pause30 = NSMenuItem(
            title: "暂停 30 分钟",
            action: #selector(pause30Minutes),
            keyEquivalent: ""
        )
        pause30.image = NSImage(
            systemSymbolName: "30.circle",
            accessibilityDescription: nil
        )
        submenu.addItem(pause30)

        let pause1h = NSMenuItem(
            title: "暂停 1 小时",
            action: #selector(pause1Hour),
            keyEquivalent: ""
        )
        pause1h.image = NSImage(
            systemSymbolName: "1.circle",
            accessibilityDescription: nil
        )
        submenu.addItem(pause1h)

        let pause3h = NSMenuItem(
            title: "暂停 3 小时",
            action: #selector(pause3Hours),
            keyEquivalent: ""
        )
        pause3h.image = NSImage(
            systemSymbolName: "3.circle",
            accessibilityDescription: nil
        )
        submenu.addItem(pause3h)

        let pause8h = NSMenuItem(
            title: "暂停 8 小时",
            action: #selector(pause8Hours),
            keyEquivalent: ""
        )
        pause8h.image = NSImage(
            systemSymbolName: "8.circle",
            accessibilityDescription: nil
        )
        submenu.addItem(pause8h)

        return submenu
    }

    private lazy var clipWinController = ClipMainWindowController.shared
    private lazy var settingWinController = SettingWindowController.shared

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

extension AppDelegate: NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        Self.shared = self

        PasteSQLManager.migrateUserDefaultsIfNeeded()

        initStatus()

        applyAppearanceSettings()

        Task {
            await initClipboardAsync()
        }
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_: Notification) {
        EventDispatcher.shared.stop()
        FileAccessHelper.shared.stopAccessingSecurityScopedResources()
    }

    private func applyAppearanceSettings() {
        let appearanceMode = AppearanceMode(
            rawValue: PasteUserDefaults.appearance,
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
}

extension AppDelegate {
    private func initClipboardAsync() async {
        PasteBoard.main.startListening()

        PasteDataStore.main.setup()

        initEvent()

        HotKeyManager.shared.initialize()

        syncLaunchAtLoginStatus()

        Task.detached(priority: .utility) {
            await FileAccessHelper.shared.restoreAllAccesses()
        }
    }

    private func syncLaunchAtLoginStatus() {
        let userDefaultsValue = PasteUserDefaults.onStart
        let actualValue = LaunchAtLoginHelper.shared.isEnabled
        if userDefaultsValue != actualValue {
            LaunchAtLoginHelper.shared.setEnabled(userDefaultsValue)
        }
    }

    private func initStatus() {
        menuBarItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength,
        )

        guard let menuBarItem else { return }

        menuBarItem.isVisible = true
        let config = NSImage.SymbolConfiguration(
            pointSize: 15,
            weight: .semibold
        )

        let iconName = "heart.text.clipboard.fill"
        let icon: NSImage? = if #available(macOS 15.0, *) {
            NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        } else {
            NSImage(named: iconName)
        }

        menuBarItem.button?.image = icon?.withSymbolConfiguration(config)
        menuBarItem.button?.target = self
        menuBarItem.button?.action = #selector(statusBarClick)
        menuBarItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
}

extension AppDelegate {
    @objc
    private func statusBarClick(sender: NSStatusBarButton) {
        guard let event = NSApplication.shared.currentEvent else { return }
        if event.type == .leftMouseUp {
            clipWinController.toggleWindow()
        } else if event.type == .rightMouseUp {
            updaterController.updater.checkForUpdatesInBackground()
            menuBarItem?.menu = rMenu
            sender.performClick(nil)
            menuBarItem?.menu = nil
        }
    }

    @objc
    private func settingsAction() {
        settingWinController.toggleWindow()
    }

    @objc
    private func checkUpdate() {
        updaterController.checkForUpdates(nil)
    }

    @objc private func resumePasteboard() {
        PasteBoard.main.resume()
    }

    @objc private func pause15Minutes() {
        PasteBoard.main.pause(for: 15 * 60)
    }

    @objc private func pause30Minutes() {
        PasteBoard.main.pause(for: 30 * 60)
    }

    @objc private func pause1Hour() {
        PasteBoard.main.pause(for: 60 * 60)
    }

    @objc private func pause3Hours() {
        PasteBoard.main.pause(for: 3 * 60 * 60)
    }

    @objc private func pause8Hours() {
        PasteBoard.main.pause(for: 8 * 60 * 60)
    }

    @objc private func pauseIndefinitely() {
        PasteBoard.main.pause()
    }

    @objc
    func triggerStatusBarPulse() {
        guard let button = menuBarItem?.button else { return }

        button.layer?.removeAnimation(forKey: "bounceAnimation")

        let bounceAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        bounceAnimation.values = [1.0, 1.2, 0.95, 1.0]
        bounceAnimation.keyTimes = [0.0, 0.4, 0.7, 1.0]
        bounceAnimation.duration = 0.6
        bounceAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        button.layer?.add(bounceAnimation, forKey: "bounceAnimation")
    }

    func toggleWindow(_ completionHandler: (() -> Void)? = nil) {
        clipWinController.toggleWindow(completionHandler)
    }

    private func initEvent() {
        EventDispatcher.shared.start()

        EventDispatcher.shared.registerHandler(
            matching: .keyDown,
            key: "setting"
        ) { [weak self] event in
            if event.modifierFlags.contains(.command) {
                let modifiers = event.charactersIgnoringModifiers
                if modifiers == "," || modifiers == "，" {
                    self?.settingWinController.toggleWindow()
                    return nil
                }
                if modifiers == "q" || modifiers == "Q" {
                    NSApplication.shared.terminate(nil)
                    return nil
                }
            }
            return event
        }
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if let pauseItem = menu.item(withTitle: "暂停")
            ?? menu.item(withTitle: "已暂停")
            ?? menu.items.first(where: { $0.title.hasPrefix("暂停到") })
        {
            pauseItem.title = pauseMenuTitle()
            pauseItem.submenu = createPauseSubmenu()
        }
    }

    private func pauseMenuTitle() -> String {
        guard PasteBoard.main.isPaused else {
            return "暂停"
        }

        if let endTime = PasteBoard.main.pauseEndTime {
            return "暂停到 \(timeFormatter.string(from: endTime))"
        }

        return "已暂停"
    }
}

// MARK: - SPUUpdaterDelegate

extension AppDelegate: SPUUpdaterDelegate {
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
}
