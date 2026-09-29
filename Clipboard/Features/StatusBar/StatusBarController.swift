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
        if let menuBarItem {
            NSStatusBar.system.removeStatusItem(menuBarItem)
            self.menuBarItem = nil
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

        let symbolName =
            if #available(macOS 15.0, *) {
                "heart.text.clipboard.fill"
            } else {
                "list.clipboard.fill"
            }
        let icon = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(config)

        icon?.isTemplate = true
        button.image = icon
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

        switch event.type {
        case .leftMouseUp:
            WindowManager.shared.toggleWindow(
                frame: sender.window?.screen?.frame
            )

        case .rightMouseUp:
            guard let menu else { return }

            menuBarItem?.menu = menu
            defer {
                menuBarItem?.menu = nil
            }

            sender.performClick(nil)

        default:
            break
        }
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

// MARK: - Menu construction

extension StatusBarController {
    private static let appName: String =
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleName"
        ) as? String ?? "Clipboard"

    private func makeItem(
        title: String, action: Selector, symbol: String,
        key: String = "", target: AnyObject? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target ?? self
        setMenuItemImage(item, symbolName: symbol)
        return item
    }

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

        let aboutItem = makeItem(
            title: String(localized: .aboutApp(Self.appName)), action: #selector(aboutAction),
            symbol: "info.circle"
        )
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let newTextItem = makeItem(
            title: String(localized: .newText), action: #selector(newTextItemAction),
            symbol: "square.and.pencil", key: "t"
        )
        newTextItem.keyEquivalentModifierMask = .command
        menu.addItem(newTextItem)

        let item1 = makeItem(
            title: String(localized: .settings), action: #selector(settingsAction),
            symbol: "gearshape", key: ","
        )
        menu.addItem(item1)

        menu.addItem(NSMenuItem.separator())

        let item2 = makeItem(
            title: String(localized: .checkUpdates), action: #selector(checkUpdateAction),
            symbol: "arrow.clockwise"
        )
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

        let restartItem = makeItem(
            title: String(localized: .restart), action: #selector(NSApplication.relaunch),
            symbol: "arrow.clockwise.circle", target: NSApplication.shared
        )
        menu.addItem(restartItem)

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

        let pause15 = makeItem(
            title: String(localized: .pauseFifteen), action: #selector(pause15Minutes),
            symbol: "15.circle"
        )
        submenu.addItem(pause15)

        let pause30 = makeItem(
            title: String(localized: .pauseThirty), action: #selector(pause30Minutes),
            symbol: "30.circle"
        )
        submenu.addItem(pause30)

        let pause1h = makeItem(
            title: String(localized: .pauseOneHour), action: #selector(pause1Hour),
            symbol: "1.circle"
        )
        submenu.addItem(pause1h)

        let pause3h = makeItem(
            title: String(localized: .pauseThreeHours), action: #selector(pause3Hours),
            symbol: "3.circle"
        )
        submenu.addItem(pause3h)

        let pause8h = makeItem(
            title: String(localized: .pauseEightHours), action: #selector(pause8Hours),
            symbol: "8.circle"
        )
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
}

// MARK: - NSMenuDelegate

extension StatusBarController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if let pauseItem = menu.items.first(where: {
            $0.tag == Self.pauseMenuTag
        }) {
            pauseItem.title = pauseMenuTitle()
            pauseItem.submenu = createPauseSubmenu()
        }
    }
}
