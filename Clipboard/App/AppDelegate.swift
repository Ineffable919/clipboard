//
//  AppDelegate.swift
//  clipboard
//
//  Created by crown on 2025/9/11.
//

import AppKit
import KeyboardShortcuts
import QuartzCore
import Sparkle

class AppDelegate: NSObject {
    static var shared: AppDelegate?

    // Sparkle
    let updaterController: SPUStandardUpdaterController =
        .init(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil,
        )

    private let menuBarItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.squareLength,
    )

    private lazy var rMenu: NSMenu = {
        let menu = NSMenu(title: "设置")

        let item1 = NSMenuItem(
            title: "偏好设置",
            action: #selector(settingsAction),
            keyEquivalent: ",",
        )
        item1.image = NSImage(
            systemSymbolName: "gearshape",
            accessibilityDescription: nil,
        )
        menu.addItem(item1)

        let item3 = NSMenuItem(
            title: "检查更新",
            action: #selector(checkUpdate),
            keyEquivalent: "",
        )
        item3.image = NSImage(
            systemSymbolName: "arrow.clockwise",
            accessibilityDescription: nil,
        )
        menu.addItem(item3)

        menu.addItem(NSMenuItem.separator())

        let item2 = NSMenuItem(
            title: "退出",
            action: #selector(NSApplication.shared.terminate),
            keyEquivalent: "q",
        )
        menu.addItem(item2)

        return menu
    }()

    private lazy var clipWinController = ClipMainWindowController.shared
    private lazy var settingWinController = SettingWindowController.shared
}

extension AppDelegate: NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        Self.shared = self
        initClipboard()
        syncLaunchAtLoginStatus()
        applyAppearanceSettings()
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_: Notification) {
        EventMonitorManager.shared.removeAllMonitors()

        FileAccessHelper.shared.stopAccessingSecurityScopedResources()
    }

    private func applyAppearanceSettings() {
        let appearanceMode =
            AppearanceMode(
                rawValue: PasteUserDefaults.appearance,
            ) ?? .system

        DispatchQueue.main.async {
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
}

extension AppDelegate {
    private func initClipboard() {
        initStatus()

        PasteBoard.main.startListening()

        PasteDataStore.main.setup()

        KeyboardShortcuts.onKeyDown(for: .toggleClipKey) { [self] in
            clipWinController.toggleWindow()
        }

        FileAccessHelper.shared.restoreAllAccesses()

        setupLocalKeyboardShortcuts()
    }

    private func syncLaunchAtLoginStatus() {
        let userDefaultsValue = PasteUserDefaults.onStart
        let actualValue = LaunchAtLoginHelper.shared.isEnabled

        if userDefaultsValue != actualValue {
            LaunchAtLoginHelper.shared.setEnabled(userDefaultsValue)
        }
    }

    private func initStatus() {
        menuBarItem.isVisible = true
        let config = NSImage.SymbolConfiguration(
            pointSize: 12,
            weight: .medium,
            scale: .large,
        )
        if #available(macOS 15.0, *) {
            menuBarItem.button?.image = NSImage(
                systemSymbolName: "heart.text.clipboard.fill",
                accessibilityDescription: "",
            )?
                .withSymbolConfiguration(config)
        } else {
            menuBarItem.button?.image = NSImage(
                named: "heart.text.clipboard.fill",
            )?
                .withSymbolConfiguration(config)
        }
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
            menuBarItem.menu = rMenu
            sender.performClick(nil)
            menuBarItem.menu = nil
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

    @objc
    func triggerStatusBarPulse() {
        guard let button = menuBarItem.button else { return }

        button.layer?.removeAnimation(forKey: "bounceAnimation")

        let bounceAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        bounceAnimation.values = [1.0, 1.2, 0.95, 1.0]
        bounceAnimation.keyTimes = [0.0, 0.4, 0.7, 1.0]
        bounceAnimation.duration = 0.6
        bounceAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [bounceAnimation]

        button.layer?.add(bounceAnimation, forKey: "bounceAnimation")
    }

    func toggleWindow(_ completionHandler: (() -> Void)? = nil) {
        clipWinController.toggleWindow(completionHandler)
    }

    private func setupLocalKeyboardShortcuts() {
        EventMonitorManager.shared.addLocalMonitor(
            type: .globalSettings,
            matching: .keyDown,
        ) { [weak self] event in
            // Cmd+, 打开设置
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers == ","
               || event.charactersIgnoringModifiers == "，"
            {
                self?.settingWinController.toggleWindow()
                return nil // 拦截事件
            }
            return event // 传播事件
        }
    }
}
