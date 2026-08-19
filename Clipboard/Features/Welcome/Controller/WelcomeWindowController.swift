//
//  WelcomeWindowController.swift
//  Clipboard
//

import AppKit
import SwiftUI

@MainActor
final class WelcomeWindowController: NSWindowController {
    static let shared = WelcomeWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: WelcomeStyle.windowWidth,
                height: WelcomeStyle.windowHeight
            ),
            styleMask: [
                .titled, .closable, .miniaturizable, .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        window.title = "Clip"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.level = .normal
        window.minSize = NSSize(
            width: WelcomeStyle.windowWidth,
            height: WelcomeStyle.windowHeight
        )
        window.maxSize = window.minSize
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.contentView = NSHostingView(rootView: WelcomeView())
        window.center()

        super.init(window: window)

        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showIfNeeded() {
        guard !PasteUserDefaults.welcomeDone else { return }

        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func skipWelcome() {
        completeWelcome(showClipboard: false)
    }

    func finishWelcome() {
        completeWelcome(showClipboard: true)
    }

    private func completeWelcome(showClipboard: Bool) {
        PasteUserDefaults.welcomeDone = true
        window?.orderOut(nil)

        if showClipboard {
            WindowManager.shared.toggleWindow(frame: NSScreen.main?.frame)
        }
    }
}

extension WelcomeWindowController: NSWindowDelegate {
    func windowShouldClose(_: NSWindow) -> Bool {
        PasteUserDefaults.welcomeDone = true
        return true
    }
}
