//
//  SettingWindowController.swift
//  Clipboard
//
//  Created on 2025/10/26.
//

import AppKit
import SwiftUI

class SettingWindowController: NSWindowController {
    static let shared = SettingWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Const.settingWidth,
                height: Const.settingHeight
            ),
            styleMask: [
                .titled, .closable, .miniaturizable, .fullSizeContentView,
            ],
            backing: .buffered,
            defer: false
        )

        window.level = .normal
        window.center()
        window.isReleasedWhenClosed = true
        window.titlebarSeparatorStyle = .none

        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor.windowBackgroundColor

        let settingView = SettingView()
        window.contentView = NSHostingView(rootView: settingView)

        super.init(window: window)

        // 设置键盘快捷键
        setupKeyboardShortcuts()
    }

    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            // Cmd+W 关闭窗口
            if event.modifierFlags.contains(.command)
                && event.charactersIgnoringModifiers == "w"
            {
                if self?.window?.isKeyWindow == true {
                    self?.hideWindow()
                    return nil
                }
            }
            // Cmd + M 最小化窗口
            if event.modifierFlags.contains(.command)
                && event.charactersIgnoringModifiers == "m"
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
        guard let window = window else { return }

        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func showWindow() {
        guard let window = window else { return }

        if !window.isVisible {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideWindow() {
        window?.orderOut(nil)
    }

    func minWindow() {
        guard let window = window else { return }

        if window.isVisible && !window.isMiniaturized {
            window.miniaturize(nil)
        }
    }
}
