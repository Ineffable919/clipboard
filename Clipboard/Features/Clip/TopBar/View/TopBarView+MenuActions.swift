//
//  TopBarView+MenuActions.swift
//  Clipboard
//
//  Created by crown on 2026/4/27.
//

import AppKit
import Sparkle

@objc protocol TopBarMenuActions {
    func openSettingsAction()
    func checkForUpdatesAction()
    func invokeHelpAction()
    func openNewTextItemAction()
    func openAboutAction()
    func resumePasteboardAction()
    func pauseIndefinitelyAction()
    func pause15MinutesAction()
    func pause30MinutesAction()
    func pause1HourAction()
    func pause3HoursAction()
    func pause8HoursAction()
}

// MARK: - TopBarMenuActions

extension TopBarView: TopBarMenuActions {
    func openSettingsAction() {
        SettingWindowController.shared.toggleWindow()
    }

    func checkForUpdatesAction() {
        AppDelegate.shared?.updaterController.checkForUpdates(nil)
    }

    func invokeHelpAction() {
        if let url = URL(
            string:
            "https://github.com/Ineffable919/clipboard/blob/master/README.md"
        ) {
            NSWorkspace.shared.open(url)
        }
    }

    func openNewTextItemAction() {
        EditWindowController.shared.openNewWindow()
    }

    func openAboutAction() {
        SettingWindowController.shared.toggleWindow(page: .about)
    }

    func resumePasteboardAction() {
        topVM?.resume()
    }

    func pauseIndefinitelyAction() {
        topVM?.pauseIndefinitely()
    }

    func pause15MinutesAction() {
        topVM?.pause(for: 15)
    }

    func pause30MinutesAction() {
        topVM?.pause(for: 30)
    }

    func pause1HourAction() {
        topVM?.pause(for: 60)
    }

    func pause3HoursAction() {
        topVM?.pause(for: 180)
    }

    func pause8HoursAction() {
        topVM?.pause(for: 480)
    }
}
