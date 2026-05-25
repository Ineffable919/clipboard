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

    private var targetVisible = false

    var isVisible: Bool {
        targetVisible
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
        if targetVisible {
            dismiss(completionHandler)
        } else {
            show(in: frame)
        }
    }
}

extension ClipMainWindowController {
    func dismiss(_ completionHandler: (@MainActor () -> Void)? = nil) {
        targetVisible = false
        guard let window, window.isVisible else { return }

        let view = window.contentViewController?.view
        let height = view?.bounds.height ?? Const.defaultHeight

        snapToPresentedPosition(view)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Const.hideDuration
            view?.animator().setFrameOrigin(NSPoint(x: 0, y: -height))
        }) {
            Task { @MainActor in
                guard !self.targetVisible else { return }
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
        targetVisible = true
        guard let window else { return }

        let view = window.contentViewController?.view
        if !window.isVisible {
            let screenFrame = frame ?? NSScreen.main?.frame ?? .zero
            AppEnvironment.shared.previousApp = NSWorkspace.shared.frontmostApplication
            let panelFrame = NSRect(x: screenFrame.minX, y: screenFrame.minY, width: screenFrame.width, height: Const.defaultHeight)
            view?.setFrameOrigin(NSPoint(x: 0, y: -Const.defaultHeight))
            window.setFrame(panelFrame, display: false)
            window.setIsVisible(true)
        } else {
            snapToPresentedPosition(window.contentViewController?.view)
        }

        window.makeKeyAndOrderFront(nil)
        if #unavailable(macOS 15.0) {
            NSApp.activate(ignoringOtherApps: true)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Const.showDuration
            view?.animator().setFrameOrigin(.zero)
        }
    }

    private func snapToPresentedPosition(_ view: NSView?) {
        guard let view else { return }
        let y = view.layer?.presentation()?.frame.origin.y ?? view.frame.origin.y
        view.layer?.removeAllAnimations()
        view.setFrameOrigin(NSPoint(x: 0, y: y))
    }
}

extension ClipMainWindowController: NSWindowDelegate {
    func windowDidResignKey(_: Notification) {
        guard !AppEnvironment.shared.suppressResignKey else { return }
        dismiss()
    }
}
