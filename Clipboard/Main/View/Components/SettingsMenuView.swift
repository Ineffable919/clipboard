//
//  SettingsMenuView.swift
//  Clipboard
//
//  Created by crown on 2026/1/29.
//

import Sparkle
import SwiftUI

struct SettingsMenuView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(PrefKey.backgroundType.rawValue)
    private var backgroundTypeRaw: Int = 0
    @State private var isHovered: Bool = false
    @State private var updateManager = UpdateManager.shared

    var topBarVM: TopBarViewModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "ellipsis")
                .font(.system(size: Const.iconSize14, weight: .regular))
                .padding(.horizontal, Const.space6)
                .padding(.vertical, Const.space10)
                .background(
                    RoundedRectangle(cornerRadius: Const.radius, style: .continuous)
                        .fill(isHovered ? hoverColor() : Color.clear)
                )
                .onHover { hovering in
                    isHovered = hovering
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showNativeMenu()
                }

            if updateManager.hasUpdate {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6.0, height: 6.0)
                    .offset(x: -Const.space4, y: Const.space4)
            }
        }
    }

    private func hoverColor() -> Color {
        if #available(macOS 26.0, *) {
            let backgroundType =
                BackgroundType(rawValue: backgroundTypeRaw) ?? .liquid
            return colorScheme == .dark
                ? Const.hoverDarkColor
                : (backgroundType == .liquid
                    ? Const.hoverLightColorLiquid
                    : Const.hoverLightColorFrosted)
        } else {
            return colorScheme == .dark
                ? Const.hoverDarkColor
                : Const.hoverLightColorFrostedLow
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

    private func showNativeMenu() {
        let menu = NSMenu()

        if updateManager.hasUpdate {
            let newVersionItem = NSMenuItem(
                title: "检测到新版本 \(updateManager.availableVersion ?? "")",
                action: #selector(MenuActions.checkForUpdates),
                keyEquivalent: ""
            )
            newVersionItem.target = MenuActions.shared
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
            menu.addItem(NSMenuItem.separator())
        } else {
            AppDelegate.shared?.updaterController.updater.checkForUpdatesInBackground()
        }

        let aboutItem = NSMenuItem(
            title: "关于 \(Self.appName)",
            action: #selector(MenuActions.openAbout),
            keyEquivalent: ""
        )
        aboutItem.target = MenuActions.shared
        setMenuItemImage(aboutItem, symbolName: "info.circle")
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let newTextItem = NSMenuItem(
            title: "新文本项",
            action: #selector(MenuActions.openNewTextItem),
            keyEquivalent: "t"
        )
        newTextItem.keyEquivalentModifierMask = .command
        newTextItem.target = MenuActions.shared
        setMenuItemImage(newTextItem, symbolName: "square.and.pencil")
        menu.addItem(newTextItem)

        let settingsItem = NSMenuItem(
            title: "设置...",
            action: #selector(MenuActions.openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = MenuActions.shared
        setMenuItemImage(settingsItem, symbolName: "gearshape")
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let updateItem = NSMenuItem(
            title: "检查更新",
            action: #selector(MenuActions.checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = MenuActions.shared
        setMenuItemImage(updateItem, symbolName: "arrow.clockwise")
        menu.addItem(updateItem)

        let helpItem = NSMenuItem(
            title: "帮助",
            action: #selector(MenuActions.invokeHelp),
            keyEquivalent: ""
        )
        helpItem.target = MenuActions.shared
        setMenuItemImage(helpItem, symbolName: "questionmark.circle")
        menu.addItem(helpItem)

        menu.addItem(NSMenuItem.separator())

        let pauseItem = NSMenuItem(
            title: topBarVM.pauseMenuTitle,
            action: nil,
            keyEquivalent: ""
        )
        setMenuItemImage(pauseItem, symbolName: "pause.circle")

        let pauseSubmenu = NSMenu()

        if topBarVM.isPaused {
            let resumeItem = NSMenuItem(
                title: "恢复",
                action: #selector(MenuActions.resumePasteboard),
                keyEquivalent: ""
            )
            resumeItem.target = MenuActions.shared
            setMenuItemImage(resumeItem, symbolName: "play.circle")
            pauseSubmenu.addItem(resumeItem)
            pauseSubmenu.addItem(NSMenuItem.separator())
        } else {
            let pauseIndefiniteItem = NSMenuItem(
                title: "暂停",
                action: #selector(MenuActions.pauseIndefinitely),
                keyEquivalent: ""
            )
            pauseIndefiniteItem.target = MenuActions.shared
            setMenuItemImage(pauseIndefiniteItem, symbolName: "pause.circle")
            pauseSubmenu.addItem(pauseIndefiniteItem)

            pauseSubmenu.addItem(NSMenuItem.separator())
        }

        let pause15Item = NSMenuItem(
            title: "暂停 15 分钟",
            action: #selector(MenuActions.pause15Minutes),
            keyEquivalent: ""
        )
        pause15Item.target = MenuActions.shared
        setMenuItemImage(pause15Item, symbolName: "15.circle")
        pauseSubmenu.addItem(pause15Item)

        let pause30Item = NSMenuItem(
            title: "暂停 30 分钟",
            action: #selector(MenuActions.pause30Minutes),
            keyEquivalent: ""
        )
        pause30Item.target = MenuActions.shared
        setMenuItemImage(pause30Item, symbolName: "30.circle")
        pauseSubmenu.addItem(pause30Item)

        let pause1hItem = NSMenuItem(
            title: "暂停 1 小时",
            action: #selector(MenuActions.pause1Hour),
            keyEquivalent: ""
        )
        pause1hItem.target = MenuActions.shared
        setMenuItemImage(pause1hItem, symbolName: "1.circle")
        pauseSubmenu.addItem(pause1hItem)

        let pause3hItem = NSMenuItem(
            title: "暂停 3 小时",
            action: #selector(MenuActions.pause3Hours),
            keyEquivalent: ""
        )
        pause3hItem.target = MenuActions.shared
        setMenuItemImage(pause3hItem, symbolName: "3.circle")
        pauseSubmenu.addItem(pause3hItem)

        let pause8hItem = NSMenuItem(
            title: "暂停 8 小时",
            action: #selector(MenuActions.pause8Hours),
            keyEquivalent: ""
        )
        pause8hItem.target = MenuActions.shared
        setMenuItemImage(pause8hItem, symbolName: "8.circle")
        pauseSubmenu.addItem(pause8hItem)

        pauseItem.submenu = pauseSubmenu
        menu.addItem(pauseItem)

        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(NSApplication.shared.terminate),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSView())
        }
    }
}

class MenuActions: NSObject {
    static let shared = MenuActions()

    @objc func openSettings() {
        SettingWindowController.shared.toggleWindow()
    }

    @objc func checkForUpdates() {
        AppDelegate.shared?.updaterController.checkForUpdates(nil)
    }

    @objc func invokeHelp() {
        if let url = URL(
            string:
            "https://github.com/Ineffable919/clipboard/blob/master/README.md"
        ) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openNewTextItem() {
        EditWindowController.shared.openNewWindow()
    }

    @objc func openAbout() {
        SettingWindowController.shared.toggleWindow(page: .about)
    }

    // MARK: - 暂停功能

    @objc func resumePasteboard() {
        PasteBoard.main.resume()
    }

    @objc func pause15Minutes() {
        PasteBoard.main.pause(for: 15 * 60)
    }

    @objc func pause30Minutes() {
        PasteBoard.main.pause(for: 30 * 60)
    }

    @objc func pause1Hour() {
        PasteBoard.main.pause(for: 60 * 60)
    }

    @objc func pause3Hours() {
        PasteBoard.main.pause(for: 3 * 60 * 60)
    }

    @objc func pause8Hours() {
        PasteBoard.main.pause(for: 8 * 60 * 60)
    }

    @objc func pauseIndefinitely() {
        PasteBoard.main.pause()
    }
}
