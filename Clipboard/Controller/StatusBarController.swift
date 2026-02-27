//
//  StatusBarController.swift
//  clipboard
//
//  Created by crown on 2026/2/27.
//

import AppKit
import QuartzCore

@MainActor
final class StatusBarController: NSObject {
    static let shared = StatusBarController()

    private var menuBarItem: NSStatusItem?
    private var menuBarIconObserver: NSObjectProtocol?

    private var onCheckUpdateClick: (() -> Void)?
    private var menu: NSMenu?

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    override private init() {
        super.init()
    }

    func setup(
        onCheckUpdateClick: @escaping () -> Void
    ) {
        self.onCheckUpdateClick = onCheckUpdateClick
        menu = createMenu()

        initializeStatusItem()
        observeMenuBarIconVisibility()
    }

    func cleanup() {
        if let observer = menuBarIconObserver {
            NotificationCenter.default.removeObserver(observer)
            menuBarIconObserver = nil
        }
    }

    func triggerPulseAnimation() {
        guard let button = menuBarItem?.button else { return }

        button.layer?.removeAnimation(forKey: "bounceAnimation")

        let bounceAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        bounceAnimation.values = [1.0, 1.2, 0.95, 1.0]
        bounceAnimation.keyTimes = [0.0, 0.4, 0.7, 1.0]
        bounceAnimation.duration = 0.6
        bounceAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        button.layer?.add(bounceAnimation, forKey: "bounceAnimation")
    }

    func updateVisibility(_ shouldShow: Bool) {
        if shouldShow {
            if menuBarItem == nil {
                initializeStatusItem()
            } else {
                menuBarItem?.isVisible = true
                configureMenuBarButton()
            }
        } else {
            menuBarItem?.isVisible = false
        }
        PasteUserDefaults.showMenuBarIcon = shouldShow
    }

    private func initializeStatusItem() {
        menuBarItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )

        guard menuBarItem != nil else { return }

        let shouldShow = PasteUserDefaults.showMenuBarIcon
        menuBarItem?.isVisible = shouldShow

        configureMenuBarButton()
    }

    private func configureMenuBarButton() {
        guard let button = menuBarItem?.button else { return }

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

        button.image = icon?.withSymbolConfiguration(config)
        button.target = self
        button.action = #selector(statusBarClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func observeMenuBarIconVisibility() {
        menuBarIconObserver = NotificationCenter.default.addObserver(
            forName: .menuBarIconVisibilityChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let shouldShow = notification.object as? Bool else { return }
            Task { @MainActor in
                self?.updateVisibility(shouldShow)
            }
        }
    }

    @objc
    private func statusBarClick(sender: NSStatusBarButton) {
        guard let event = NSApplication.shared.currentEvent else { return }

        if event.type == .leftMouseUp {
            WindowManager.shared.toggleWindow()
        } else if event.type == .rightMouseUp {
            guard let menu else { return }
            menuBarItem?.menu = menu
            sender.performClick(nil)
            menuBarItem?.menu = nil
        }
    }

    private func createMenu() -> NSMenu {
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
        item1.target = self
        menu.addItem(item1)

        let item2 = NSMenuItem(
            title: "检查更新",
            action: #selector(checkUpdateAction),
            keyEquivalent: ""
        )
        item2.image = NSImage(
            systemSymbolName: "arrow.clockwise",
            accessibilityDescription: nil
        )
        item2.target = self
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
    }

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
            resumeItem.target = self
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
            pauseIndefinite.target = self
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
        pause15.target = self
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
        pause30.target = self
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
        pause1h.target = self
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
        pause3h.target = self
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
        pause8h.target = self
        submenu.addItem(pause8h)

        return submenu
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

    @objc private func settingsAction() {
        SettingWindowController.shared.toggleWindow()
    }

    @objc private func checkUpdateAction() {
        onCheckUpdateClick?()
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
}

// MARK: - NSMenuDelegate

extension StatusBarController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if let pauseItem = menu.item(withTitle: "暂停")
            ?? menu.item(withTitle: "已暂停")
            ?? menu.items.first(where: { $0.title.hasPrefix("暂停到") })
        {
            pauseItem.title = pauseMenuTitle()
            pauseItem.submenu = createPauseSubmenu()
        }
    }
}
