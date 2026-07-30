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
               )
            {
                let config = NSImage.SymbolConfiguration(
                    pointSize: 16.0,
                    weight: .semibold
                )
                image.isTemplate = true
                newVersionItem.image = image.withSymbolConfiguration(config)
            }
            menu.addItem(newVersionItem)
            menu.addItem(.separator())
        } else {
            AppDelegate.shared?.updaterController.updater.checkForUpdatesInBackground()
        }

        let aboutItem = NSMenuItem(
            title: String(localized: .aboutApp(Self.appName)),
            action: #selector(TopBarMenuActions.openAboutAction),
            keyEquivalent: ""
        )
        aboutItem.target = target
        setMenuItemImage(aboutItem, symbolName: "info.circle")
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let newTextItem = NSMenuItem(
            title: String(localized: .newText),
            action: #selector(TopBarMenuActions.openNewTextItemAction),
            keyEquivalent: "t"
        )
        newTextItem.keyEquivalentModifierMask = .command
        newTextItem.target = target
        setMenuItemImage(newTextItem, symbolName: "square.and.pencil")
        menu.addItem(newTextItem)

        let settingsItem = NSMenuItem(
            title: String(localized: .settings),
            action: #selector(TopBarMenuActions.openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = target
        setMenuItemImage(settingsItem, symbolName: "gearshape")
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let updateItem = NSMenuItem(
            title: String(localized: .checkUpdates),
            action: #selector(TopBarMenuActions.checkForUpdatesAction),
            keyEquivalent: ""
        )
        updateItem.target = target
        setMenuItemImage(updateItem, symbolName: "arrow.clockwise")
        menu.addItem(updateItem)

        let helpItem = NSMenuItem(
            title: String(localized: .menuHelp),
            action: #selector(TopBarMenuActions.invokeHelpAction),
            keyEquivalent: ""
        )
        helpItem.target = target
        setMenuItemImage(helpItem, symbolName: "questionmark.circle")
        menu.addItem(helpItem)

        menu.addItem(.separator())

        let pauseItem = NSMenuItem(
            title: topVM?.pauseMenuTitle ?? String(localized: .pause),
            action: nil,
            keyEquivalent: ""
        )
        setMenuItemImage(pauseItem, symbolName: "pause.circle")
        pauseItem.submenu = buildPauseSubmenu()
        menu.addItem(pauseItem)

        let quitItem = NSMenuItem(
            title: String(localized: .quit),
            action: #selector(NSApplication.shared.terminate),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        return menu
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

        let durations: [(String, String, Selector)] = [
            (
                String(localized: .pauseFifteen), "15.circle",
                #selector(TopBarMenuActions.pause15MinutesAction)
            ),
            (
                String(localized: .pauseThirty), "30.circle",
                #selector(TopBarMenuActions.pause30MinutesAction)
            ),
            (
                String(localized: .pauseOneHour), "1.circle",
                #selector(TopBarMenuActions.pause1HourAction)
            ),
            (
                String(localized: .pauseThreeHours), "3.circle",
                #selector(TopBarMenuActions.pause3HoursAction)
            ),
            (
                String(localized: .pauseEightHours), "8.circle",
                #selector(TopBarMenuActions.pause8HoursAction)
            ),
        ]

        for (title, symbol, selector) in durations {
            let item = NSMenuItem(
                title: title,
                action: selector,
                keyEquivalent: ""
            )
            item.target = target
            setMenuItemImage(item, symbolName: symbol)
            submenu.addItem(item)
        }

        return submenu
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
