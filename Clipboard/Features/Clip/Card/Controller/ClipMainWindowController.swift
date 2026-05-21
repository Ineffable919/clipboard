//
//  ClipMainWindowController.swift
//  clip
//
//  Created by crown on 2025/7/23.
//

import AppKit
import Combine

final class ClipMainWindowController: NSWindowController {
    static let shared = ClipMainWindowController()

    private var isShowing = false

    var isVisible: Bool {
        isShowing
    }

    private let db = PasteDataStore.main

    init() {
        let panel = ClipWindowView(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 0,
                height: Const.defaultHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = ClipMainViewController()
        super.init(window: panel)
        setupWindow()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWindow() {
        guard let win = window as? ClipWindowView else { return }

        win.delegate = self

        win.configureCommonSettings()

        win.level = .statusBar
        win.isOpaque = false
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
    }

    func resetState() {
        (contentViewController as? ClipMainViewController)?.resetState()
    }

    func configureWindowSharing() {
        guard let win = window as? ClipWindowView else { return }
        win.configureWindowSharing(
            showDuringScreenShare: PasteUserDefaults.showDuringScreenShare
        )
    }

    func toggleWindow(
        _ frame: NSRect? = nil,
        _ completionHandler: (@MainActor () -> Void)? = nil
    ) {
        if isVisible {
            dismiss(completionHandler)
        } else {
            show(in: frame)
        }
    }
}

extension ClipMainWindowController {
    func dismiss(_ completionHandler: (@MainActor () -> Void)? = nil) {
        guard isShowing, let window else { return }
        isShowing = false
        let view = window.contentViewController?.view
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Const.hideDuration
            view?.animator().setFrameOrigin(
                NSPoint(x: 0, y: -(view?.bounds.height ?? Const.defaultHeight))
            )
        }) {
            Task { @MainActor in
                self.window?.setIsVisible(false)
                if #unavailable(macOS 15.0) {
                    AppEnvironment.shared.previousApp?.activate(options: [])
                }
                self.window?.orderOut(nil)
                completionHandler?()
            }
        }
    }

    func show(in frame: NSRect?) {
        guard let window else { return }
        guard !isShowing else {
            return
        }
        isShowing = true
        let frame = frame ?? NSScreen.main?.frame ?? .zero
        AppEnvironment.shared.previousApp = NSWorkspace.shared.frontmostApplication
        window.setFrame(frame, display: true)
        window.setIsVisible(true)
        window.makeKeyAndOrderFront(nil)
        if #unavailable(macOS 15.0) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

extension ClipMainWindowController: NSWindowDelegate {
    func windowDidResignKey(_: Notification) {
        guard !AppEnvironment.shared.suppressResignKey else { return }
        dismiss()
    }
}
