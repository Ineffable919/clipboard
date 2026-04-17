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
    var isAnimating = false

    init() {
        let panel = ClipWindowView(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 0,
                height: Const.defaultHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
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

        win.configureCommonSettings()

        win.level = .statusBar
        win.isOpaque = false
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]

        win.delegate = self
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
        guard !isAnimating else { return }
        if isVisible {
            dismiss(completionHandler)
        } else {
            show(in: frame)
        }
    }
}

extension ClipMainWindowController {
    func dismiss(_ completionHandler: (@MainActor () -> Void)? = nil) {
        guard !isAnimating, isVisible else { return }
        isAnimating = true

        let view = window?.contentViewController?.view
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Const.hideDuration
            view?.animator().setFrameOrigin(
                NSPoint(x: 0, y: -(view?.bounds.height ?? Const.defaultHeight))
            )
        }) {
            Task { @MainActor in
                self.window?.setIsVisible(false)
                self.isAnimating = false
                completionHandler?()
            }
        }
    }

    func show(in frame: NSRect?) {
        guard !isAnimating else { return }
        isAnimating = true

        let frame = frame ?? NSScreen.main?.frame ?? .zero
        AppEnvironment.shared.previousApp = NSWorkspace.shared.frontmostApplication
        window?.setFrame(frame, display: true)
        window?.setIsVisible(true)
        window?.orderFrontRegardless()
        window?.makeKey()
    }
}

extension ClipMainWindowController: NSWindowDelegate {
    func windowDidResignKey(_: Notification) {
        guard !AppEnvironment.shared.suppressResignKey else { return }
        dismiss()
    }
}
