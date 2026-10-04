//
//  TopBarMenuBuilder.swift
//  Clipboard
//
//  Created by crown on 2026/4/27.
//

import AppKit
import Sparkle

struct TopBarMenuBuilder {
    weak var target: AnyObject?
    let topVM: TopBarViewModel?

    private static let appName: String =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Clipboard"

    // MARK: - Public

    @MainActor
    func buildSettingsMenu() -> NSMenu {
        let menu = NSMenu()
        addUpdateNotice(to: menu)

        let aboutItem = makeItem(
            title: String(localized: .aboutApp(Self.appName)), action: #selector(TopBarMenuActions.openAboutAction),
            symbol: "info.circle"
        )
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let newTextItem = makeItem(
            title: String(localized: .newText), action: #selector(TopBarMenuActions.openNewTextItemAction),
            symbol: "square.and.pencil", key: "t"
        )
        newTextItem.keyEquivalentModifierMask = .command
        menu.addItem(newTextItem)

        let settingsItem = makeItem(
            title: String(localized: .settings), action: #selector(TopBarMenuActions.openSettingsAction),
            symbol: "gearshape", key: ","
        )
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let updateItem = makeItem(
            title: String(localized: .checkUpdates), action: #selector(TopBarMenuActions.checkForUpdatesAction),
            symbol: "arrow.clockwise"
        )
        menu.addItem(updateItem)

        let helpItem = makeItem(
            title: String(localized: .menuHelp), action: #selector(TopBarMenuActions.invokeHelpAction),
            symbol: "questionmark.circle"
        )
        menu.addItem(helpItem)

        menu.addItem(.separator())

        addApplicationItems(to: menu)

        return menu
    }

    private func addApplicationItems(to menu: NSMenu) {
        let pauseItem = NSMenuItem(
            title: topVM?.pauseMenuTitle ?? String(localized: .pause),
            action: nil,
            keyEquivalent: ""
        )
        setMenuItemImage(pauseItem, symbolName: "pause.circle")
        pauseItem.submenu = buildPauseSubmenu()
        menu.addItem(pauseItem)

        let restartItem = makeItem(
            title: String(localized: .restart), action: #selector(NSApplication.relaunch),
            symbol: "arrow.clockwise.circle", target: NSApplication.shared
        )
        menu.addItem(restartItem)

        let quitItem = NSMenuItem(
            title: String(localized: .quit),
            action: #selector(NSApplication.shared.terminate),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
    }

    @MainActor
    private func addUpdateNotice(to menu: NSMenu) {
        let updateManager = UpdateManager.shared

        if updateManager.hasUpdate {
            let newVersionItem = NSMenuItem(
                title: String(
                    localized: .updateAvailable(
                        updateManager.availableVersion ?? ""
                    )
                ),
                action: #selector(TopBarMenuActions.checkForUpdatesAction),
                keyEquivalent: ""
            )
            newVersionItem.target = target
            if #available(macOS 26.0, *),
               let image = NSImage(
                   systemSymbolName: "arrow.up.circle.dotted",
                   accessibilityDescription: nil
               ) {
                let config = NSImage.SymbolConfiguration(
                    pointSize: 16.0,
                    weight: .semibold
                )
                image.isTemplate = true
                newVersionItem.image = image.withSymbolConfiguration(config)
            }
            menu.addItem(newVersionItem)
            menu.addItem(.separator())
        }
    }

    // MARK: - Private

    private func buildPauseSubmenu() -> NSMenu {
        let submenu = NSMenu()
        let isPaused = PasteBoard.main.isPaused

        if isPaused {
            let resumeItem = NSMenuItem(
                title: String(localized: .resume),
                action: #selector(TopBarMenuActions.resumePasteboardAction),
                keyEquivalent: ""
            )
            resumeItem.target = target
            setMenuItemImage(resumeItem, symbolName: "play.circle")
            submenu.addItem(resumeItem)
            submenu.addItem(.separator())
        } else {
            let pauseIndefiniteItem = NSMenuItem(
                title: String(localized: .pause),
                action: #selector(TopBarMenuActions.pauseIndefinitelyAction),
                keyEquivalent: ""
            )
            pauseIndefiniteItem.target = target
            setMenuItemImage(pauseIndefiniteItem, symbolName: "pause.circle")
            submenu.addItem(pauseIndefiniteItem)
            submenu.addItem(.separator())
        }

        let items = [
            makeItem(
                title: String(localized: .pauseFifteen),
                action: #selector(TopBarMenuActions.pause15MinutesAction), symbol: "15.circle"
            ),
            makeItem(
                title: String(localized: .pauseThirty),
                action: #selector(TopBarMenuActions.pause30MinutesAction), symbol: "30.circle"
            ),
            makeItem(
                title: String(localized: .pauseOneHour),
                action: #selector(TopBarMenuActions.pause1HourAction), symbol: "1.circle"
            ),
            makeItem(
                title: String(localized: .pauseThreeHours),
                action: #selector(TopBarMenuActions.pause3HoursAction), symbol: "3.circle"
            ),
            makeItem(
                title: String(localized: .pauseEightHours),
                action: #selector(TopBarMenuActions.pause8HoursAction), symbol: "8.circle"
            )
        ]
        for item in items {
            submenu.addItem(item)
        }

        return submenu
    }

    private func makeItem(
        title: String, action: Selector, symbol: String,
        key: String = "", target: AnyObject? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target ?? self.target
        setMenuItemImage(item, symbolName: symbol)
        return item
    }

    private func setMenuItemImage(_ item: NSMenuItem, symbolName: String) {
        if #available(macOS 26.0, *) {
            item.image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: nil
            )
        }
    }
}
