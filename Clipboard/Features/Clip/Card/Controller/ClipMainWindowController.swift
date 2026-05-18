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

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    private let db = PasteDataStore.main

    private enum Intent { case shown, hidden }
    private var intent: Intent = .hidden
    private var intentVersion: Int = 0

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
        switch intent {
        case .shown:
            dismiss(completionHandler)
        case .hidden:
            show(in: frame)
        }
    }
}

extension ClipMainWindowController {
    func dismiss(_ completionHandler: (@MainActor () -> Void)? = nil) {
        guard intent == .shown else {
            completionHandler?()
            return
        }

        intent = .hidden
        intentVersion &+= 1
        let myVersion = intentVersion

        let view = window?.contentViewController?.view
        let height = view?.bounds.height ?? Const.defaultHeight

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Const.hideDuration
            view?.animator().setFrameOrigin(NSPoint(x: 0, y: -height))
        }) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                guard self.intentVersion == myVersion else { return }
                self.window?.setIsVisible(false)
                if #unavailable(macOS 15.0) {
                    AppEnvironment.shared.previousApp?.activate(options: [])
                }
                completionHandler?()
            }
        }
    }

    func show(in frame: NSRect?) {
        intent = .shown
        intentVersion &+= 1

        let view = window?.contentViewController?.view

        if window?.isVisible != true {
            AppEnvironment.shared.previousApp = NSWorkspace.shared.frontmostApplication

            let targetFrame = frame ?? NSScreen.main?.frame ?? .zero
            if #unavailable(macOS 15.0) {
                NSApp.activate(ignoringOtherApps: true)
            }
            if window?.frame != targetFrame {
                window?.setFrame(targetFrame, display: false)
            }
            let height = view?.bounds.height ?? Const.defaultHeight
            view?.setFrameOrigin(NSPoint(x: 0, y: -height))
            window?.makeKeyAndOrderFront(nil)
        } else {
            window?.makeKeyAndOrderFront(nil)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Const.showDuration
            view?.animator().setFrameOrigin(.zero)
        }
    }
}

extension ClipMainWindowController: NSWindowDelegate {
    func windowDidResignKey(_: Notification) {
        guard !AppEnvironment.shared.suppressResignKey else { return }
        dismiss()
    }
}
