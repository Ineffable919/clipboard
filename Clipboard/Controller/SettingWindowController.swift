//
//  SettingWindowController.swift
//  Clipboard
//
//  Created on crown 2025/10/26.
//

import AppKit
import SwiftUI

class SettingWindowController: NSWindowController {
    static let shared = SettingWindowController()
    private static var settingView = SettingView()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Const.settingWidth,
                height: Const.settingHeight,
            ),
            styleMask: [
                .titled, .closable, .miniaturizable, .fullSizeContentView,
            ],
            backing: .buffered,
            defer: false,
        )

        window.level = .normal
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarSeparatorStyle = .none

        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor.windowBackgroundColor

        window.contentView = NSHostingView(rootView: Self.settingView)

        super.init(window: window)

        setupKeyboardShortcuts()
    }

    private func setupKeyboardShortcuts() {
        EventDispatcher.shared.registerHandler(
            matching: .keyDown,
            key: "settingWindow"
        ) {
            [weak self] event in
            guard event.window === SettingWindowController.shared.window else {
                return event
            }
            // Cmd+W 关闭窗口
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers == "w"
            {
                if self?.window?.isKeyWindow == true {
                    self?.hideWindow()
                    return nil
                }
            }
            // Cmd + M 最小化窗口
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers == "m"
            {
                if self?.window?.isKeyWindow == true {
                    self?.minWindow()
                    return nil
                }
            }
            return event
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggleWindow() {
        guard let window else { return }

        if window.isVisible {
            window.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    func hideWindow() {
        window?.orderOut(nil)
    }

    func minWindow() {
        guard let window else { return }

        if window.isVisible, !window.isMiniaturized {
            window.miniaturize(nil)
        }
    }
}
