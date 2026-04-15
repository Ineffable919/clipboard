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
    private var settingView = SettingView()

    private var localEventMonitor: Any?

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
        window.isReleasedWhenClosed = false
        window.titlebarSeparatorStyle = .none
        window.titlebarAppearsTransparent = true

        window.contentView = NSHostingView(rootView: settingView)

        super.init(window: window)
    }

    private func registerLocalEventMonitor() {
        guard localEventMonitor == nil else { return }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event) ?? event
        }
    }

    private func removeLocalEventMonitor() {
        if let token = localEventMonitor {
            NSEvent.removeMonitor(token)
            localEventMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard event.window === window else { return event }

        // Cmd+W — hide window
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "w"
        {
            hideWindow()
            return nil
        }

        // Cmd+M — minimise window
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "m"
        {
            minWindow()
            return nil
        }

        return event
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggleWindow() {
        guard let window else { return }

        NSApp.activate(ignoringOtherApps: true)

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        registerLocalEventMonitor()
        window.makeKeyAndOrderFront(nil)
    }

    func toggleWindow(page: SettingPage) {
        toggleWindow()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            NotificationCenter.default.post(
                name: .navigateToSettingPage,
                object: page
            )
        }
    }

    func hideWindow() {
        removeLocalEventMonitor()
        window?.orderOut(nil)
    }

    func minWindow() {
        guard let window else { return }

        if window.isVisible, !window.isMiniaturized {
            window.miniaturize(nil)
        }
    }
}
