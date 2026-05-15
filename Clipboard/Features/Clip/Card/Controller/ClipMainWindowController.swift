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

    // toggleWindow 看 intent 而非 window.isVisible，因为隐藏动画期间 isVisible 仍是 true。
    // dismiss completion 用 intentVersion 防止在动画中被新的 show 抢占后仍把窗口隐藏掉。
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
                if self.intentVersion == myVersion {
                    self.window?.resignFirstResponder()
                    self.window?.setIsVisible(false)
                    if #unavailable(macOS 15.0) {
                        AppEnvironment.shared.previousApp?.activate(options: [])
                    }
                }
                completionHandler?()
            }
        }
    }

    func show(in frame: NSRect?) {
        intent = .shown
        intentVersion &+= 1

        if window?.isVisible != true {
            let frame = frame ?? NSScreen.main?.frame ?? .zero
            AppEnvironment.shared.previousApp = NSWorkspace.shared.frontmostApplication
            if #unavailable(macOS 15.0) {
                NSApp.activate(ignoringOtherApps: true)
            }
            window?.setFrame(frame, display: true)
            window?.setIsVisible(true)
            window?.makeKeyAndOrderFront(nil)
        } else {
            window?.makeKeyAndOrderFront(nil)
        }

        let view = window?.contentViewController?.view

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
