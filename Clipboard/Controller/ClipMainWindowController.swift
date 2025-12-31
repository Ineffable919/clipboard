//
//  ClipMainWindowController.swift
//  clip
//
//  Created by crown on 2025/7/23.
//

import AppKit
import Combine

@Observable
final class ClipMainWindowController: NSWindowController {
    private let viewHeight: CGFloat = 330.0

    static let shared = ClipMainWindowController()
    var isVisible: Bool { window?.isVisible ?? false }

    var preApp: NSRunningApplication?

    private let clipVC = ClipMainViewController()
    @ObservationIgnored private lazy var env = clipVC.env
    private let db = PasteDataStore.main

    init() {
        let panel = ClipWindowView(contentViewController: clipVC)
        super.init(window: panel)
        setupWindow()
        layoutToBottom()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWindow() {
        guard let win = window as? NSPanel else { return }

        win.styleMask = [.borderless, .nonactivatingPanel]
        win.level = .statusBar

        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovable = false
        win.isMovableByWindowBackground = false
        win.hidesOnDeactivate = false
        win.isReleasedWhenClosed = false
        win.collectionBehavior = [.canJoinAllSpaces]

        win.ignoresMouseEvents = true
        win.delegate = self

        configureWindowSharing()
    }

    func configureWindowSharing() {
        guard let win = window else { return }

        let shouldShow = PasteUserDefaults.showDuringScreenShare
        win.sharingType = shouldShow ? .readOnly : .none
    }

    func layoutToBottom(screen: NSScreen? = NSScreen.main) {
        guard let screen else { return }
        let f = screen.frame
        let rect = NSRect(
            x: f.minX,
            y: f.minY,
            width: f.width,
            height: viewHeight,
        )
        window?.setFrame(rect, display: true)
    }

    func toggleWindow(_ completionHandler: (() -> Void)? = nil) {
        setPresented(!clipVC.isPresented, animated: true, completionHandler)
    }

    func setPresented(
        _ presented: Bool,
        animated: Bool,
        _ completionHandler: (() -> Void)? = nil,
    ) {
        guard let win = window else { return }

        if presented {
            if !win.isVisible {
                preApp = NSWorkspace.shared.frontmostApplication
                layoutToBottom()
                win.orderFront(nil)
            }
            win.ignoresMouseEvents = false
            win.makeKey()

            clipVC.setPresented(true, animated: animated, completion: nil)
        } else {
            win.ignoresMouseEvents = true
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
        if env.isShowDel {
            return
        }
        setPresented(false, animated: true)
    }
}
