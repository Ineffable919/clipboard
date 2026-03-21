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

    override private init() {
        super.init()
    }

    private static let pauseMenuTag = 919

    private func pauseTimeString(from date: Date) -> String {
        date.formatted(
            .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
        )
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

    private static let appName: String = Bundle.main.object(
        forInfoDictionaryKey: "CFBundleName"
    ) as? String ?? "Clipboard"

    private func setMenuItemImage(
        _ item: NSMenuItem,
        symbolName: String
    ) {
        if #available(macOS 26.0, *) {
            item.image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: nil
            )
        }
    }

    private func createMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: .settings))

        let aboutItem = NSMenuItem(
            title: String(localized: .aboutApp(Self.appName)),
            action: #selector(aboutAction),
            keyEquivalent: ""
        )
        setMenuItemImage(aboutItem, symbolName: "info.circle")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let newTextItem = NSMenuItem(
            title: String(localized: .newText),
            action: #selector(newTextItemAction),
            keyEquivalent: "t"
        )
        newTextItem.keyEquivalentModifierMask = .command
        setMenuItemImage(newTextItem, symbolName: "square.and.pencil")
        newTextItem.target = self
        menu.addItem(newTextItem)

        let item1 = NSMenuItem(
            title: String(localized: .settings),
            action: #selector(settingsAction),
            keyEquivalent: ","
        )
        setMenuItemImage(item1, symbolName: "gearshape")
        item1.target = self
        menu.addItem(item1)

        menu.addItem(NSMenuItem.separator())

        let item2 = NSMenuItem(
            title: String(localized: .checkUpdates),
            action: #selector(checkUpdateAction),
            keyEquivalent: ""
        )
        setMenuItemImage(item2, symbolName: "arrow.clockwise")
        item2.target = self
        menu.addItem(item2)

        menu.addItem(NSMenuItem.separator())

        let pauseItem = NSMenuItem(
            title: String(localized: .pause),
            action: nil,
            keyEquivalent: ""
        )
        pauseItem.tag = Self.pauseMenuTag
        setMenuItemImage(pauseItem, symbolName: "pause.circle")
        pauseItem.submenu = createPauseSubmenu()
        menu.addItem(pauseItem)

        let item3 = NSMenuItem(
            title: String(localized: .quit),
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
                title: String(localized: .resume),
                action: #selector(resumePasteboard),
                keyEquivalent: ""
            )
            setMenuItemImage(resumeItem, symbolName: "play.circle")
            resumeItem.target = self
            submenu.addItem(resumeItem)
            submenu.addItem(NSMenuItem.separator())
        } else {
            let pauseIndefinite = NSMenuItem(
                title: String(localized: .pause),
                action: #selector(pauseIndefinitely),
                keyEquivalent: ""
            )
            setMenuItemImage(pauseIndefinite, symbolName: "pause.circle")
            pauseIndefinite.target = self
            submenu.addItem(pauseIndefinite)

            submenu.addItem(NSMenuItem.separator())
        }

        let pause15 = NSMenuItem(
            title: String(localized: .pauseFifteen),
            action: #selector(pause15Minutes),
            keyEquivalent: ""
        )
        setMenuItemImage(pause15, symbolName: "15.circle")
        pause15.target = self
        submenu.addItem(pause15)

        let pause30 = NSMenuItem(
            title: String(localized: .pauseThirty),
            action: #selector(pause30Minutes),
            keyEquivalent: ""
        )
        setMenuItemImage(pause30, symbolName: "30.circle")
        pause30.target = self
        submenu.addItem(pause30)

        let pause1h = NSMenuItem(
            title: String(localized: .pauseOneHour),
            action: #selector(pause1Hour),
            keyEquivalent: ""
        )
        setMenuItemImage(pause1h, symbolName: "1.circle")
        pause1h.target = self
        submenu.addItem(pause1h)

        let pause3h = NSMenuItem(
            title: String(localized: .pauseThreeHours),
            action: #selector(pause3Hours),
            keyEquivalent: ""
        )
        setMenuItemImage(pause3h, symbolName: "3.circle")
        pause3h.target = self
        submenu.addItem(pause3h)

        let pause8h = NSMenuItem(
            title: String(localized: .pauseEightHours),
            action: #selector(pause8Hours),
            keyEquivalent: ""
        )
        setMenuItemImage(pause8h, symbolName: "8.circle")
        pause8h.target = self
        submenu.addItem(pause8h)

        return submenu
    }

    private func pauseMenuTitle() -> String {
        guard PasteBoard.main.isPaused else {
            return String(localized: .pause)
        }

        if let endTime = PasteBoard.main.pauseEndTime {
            return String(
                localized: .pauseUntil(pauseTimeString(from: endTime))
            )
        }

        return String(localized: .paused)
    }

    @objc private func settingsAction() {
        SettingWindowController.shared.toggleWindow()
    }

    @objc private func checkUpdateAction() {
        onCheckUpdateClick?()
    }

    @objc private func newTextItemAction() {
        EditWindowController.shared.openNewWindow()
    }

    @objc private func aboutAction() {
        SettingWindowController.shared.toggleWindow(page: .about)
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
        if let pauseItem = menu.items.first(where: { $0.tag == Self.pauseMenuTag }) {
            pauseItem.title = pauseMenuTitle()
            pauseItem.submenu = createPauseSubmenu()
        }
    }
}
