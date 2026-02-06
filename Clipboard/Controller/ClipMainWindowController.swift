//
//  ClipMainWindowController.swift
//  clip
//
//  Created by crown on 2025/7/23.
//

import AppKit
import Combine

final class ClipMainWindowController: NSWindowController {
    private let viewHeight: CGFloat = 330.0

    static let shared = ClipMainWindowController()
    var isVisible: Bool {
        window?.isVisible ?? false
    }

    private let clipVC = ClipMainViewController()
    private let db = PasteDataStore.main

    init() {
        let panel = ClipWindowView(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: viewHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = clipVC
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
        win.isMovable = false
        win.isMovableByWindowBackground = false
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]

        win.delegate = self
    }

    func configureWindowSharing() {
        guard let win = window as? ClipWindowView else { return }
        win.configureWindowSharing(
            showDuringScreenShare: PasteUserDefaults.showDuringScreenShare
        )
    }

    func layoutToBottom(screen: NSScreen? = NSScreen.main) {
        guard let screen else { return }
        let f = screen.frame
        let rect = NSRect(
            x: f.minX,
            y: f.minY,
            width: f.width,
            height: viewHeight
        )
        window?.setFrame(rect, display: true)
    }

    func toggleWindow(_ completionHandler: (() -> Void)? = nil) {
        setPresented(!clipVC.isPresented, animated: true, completionHandler)
    }

    func setPresented(
        _ presented: Bool,
        animated: Bool,
        _ completionHandler: (() -> Void)? = nil
    ) {
        guard let win = window else { return }

        if presented {
            if !win.isVisible {
                clipVC.env.preApp = NSWorkspace.shared.frontmostApplication
                layoutToBottom()
                win.orderFrontRegardless()
            }
            win.makeKey()

            clipVC.env.resetQuickPasteState()

            clipVC.setPresented(true, animated: animated, completion: nil)
        } else {
            clipVC.setPresented(false, animated: animated) { [weak self] in
                self?.window?.orderOut(nil)
                completionHandler?()
                Task { [weak self] in
                    self?.db.clearExpiredData()
                }
            }
        }
    }
}

extension ClipMainWindowController: NSWindowDelegate {
    func windowDidResignKey(_: Notification) {
        if clipVC.env.isShowDel {
            return
        }
        setPresented(false, animated: true)
    }
}
