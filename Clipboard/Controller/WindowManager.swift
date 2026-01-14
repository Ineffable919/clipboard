//
//  WindowManager.swift
//  Clipboard
//
//  Created by crown on 2025/1/14.
//

import AppKit
import Foundation

final class WindowManager {
    static let shared = WindowManager()

    private let drawerController = ClipMainWindowController.shared
    private let floatingController = ClipFloatingWindowController.shared

    private init() {}

    private func getCurrentDisplayMode() -> DisplayMode {
        let rawValue = UserDefaults.standard.integer(forKey: PrefKey.displayMode.rawValue)
        return DisplayMode(rawValue: rawValue) ?? .drawer
    }

    func toggleWindow(_ completionHandler: (() -> Void)? = nil) {
        let mode = getCurrentDisplayMode()

        switch mode {
        case .drawer:
            if floatingController.isVisible {
                floatingController.setPresented(false, animated: false)
            }
            drawerController.toggleWindow(completionHandler)
        case .floating:
            if drawerController.isVisible {
                drawerController.setPresented(false, animated: false)
            }
            floatingController.toggleWindow(completionHandler)
        }
    }

    func setPresented(
        _ presented: Bool,
        animated: Bool,
        _ completionHandler: (() -> Void)? = nil
    ) {
        let mode = getCurrentDisplayMode()

        switch mode {
        case .drawer:
            if floatingController.isVisible {
                floatingController.setPresented(false, animated: false)
            }
            drawerController.setPresented(presented, animated: animated, completionHandler)
        case .floating:
            if drawerController.isVisible {
                drawerController.setPresented(false, animated: false)
            }
            floatingController.setPresented(presented, animated: animated, completionHandler)
        }
    }

    var isVisible: Bool {
        drawerController.isVisible || floatingController.isVisible
    }

    var window: NSWindow? {
        let mode = getCurrentDisplayMode()
        switch mode {
        case .drawer:
            return drawerController.window
        case .floating:
            return floatingController.window
        }
    }

    func configureWindowSharing() {
        let mode = getCurrentDisplayMode()
        switch mode {
        case .drawer:
            drawerController.configureWindowSharing()
        case .floating:
            floatingController.configureWindowSharing()
        }
    }
}
