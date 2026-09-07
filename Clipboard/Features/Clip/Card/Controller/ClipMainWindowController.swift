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

    private var slideAnimationGeneration = 0

    var isVisible: Bool {
        targetVisible
    }

    private let dataStore = PasteDataStore.main

    init() {
        let initialWidth: CGFloat
        if #available(macOS 26.0, *) {
            initialWidth = NSScreen.main?.frame.width ?? Const.defaultHeight
        } else {
            initialWidth = 0
        }
        let panel = ClipWindowView(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: initialWidth,
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
        if #available(macOS 26.0, *) {
            guard targetVisible, let window, window.isVisible else { return }
            targetVisible = false
            animateContent(visible: false) { [weak self] in
                self?.window?.setIsVisible(false)
                self?.window?.orderOut(nil)
                completionHandler?()
            }
            return
        }

        targetVisible = false
        guard let window, window.isVisible else { return }

        let view = window.contentViewController?.view
        let height = view?.bounds.height ?? Const.defaultHeight

        snapToPresentedPosition(view)

        suppressSearchFocusRing(true)
        slideAnimationGeneration += 1

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Const.hideDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view?.animator().setFrameOrigin(NSPoint(x: 0, y: -height))
        }, completionHandler: {
            Task { @MainActor in
                guard !self.targetVisible else { return }
                self.window?.setIsVisible(false)
                if #unavailable(macOS 15.0) {
                    AppEnvironment.shared.previousApp?.activate(options: [])
                }
                self.window?.orderOut(nil)
                completionHandler?()
            }
        })
    }

    func show(in frame: NSRect?) {
        if #available(macOS 26.0, *) {
            showWindow(in: frame)
            return
        }

        targetVisible = true
        guard let window else { return }

        let view = window.contentViewController?.view
        if !window.isVisible {
            let screenFrame = frame ?? NSScreen.main?.frame ?? .zero
            AppEnvironment.shared.previousApp = NSWorkspace.shared.frontmostApplication
            let panelFrame = NSRect(
                x: screenFrame.minX, y: screenFrame.minY,
                width: screenFrame.width, height: Const.defaultHeight
            )
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

        suppressSearchFocusRing(true)
        slideAnimationGeneration += 1
        let generation = slideAnimationGeneration

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Const.showDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view?.animator().setFrameOrigin(.zero)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, generation == self.slideAnimationGeneration, self.targetVisible else { return }
                self.suppressSearchFocusRing(false)
            }
        }
    }

    @available(macOS 26.0, *)
    private func showWindow(in frame: NSRect?) {
        guard let window else { return }
        targetVisible = true
        let initiallyHidden = !window.isVisible

        if initiallyHidden {
            let screenFrame = frame ?? NSScreen.main?.frame ?? .zero
            AppEnvironment.shared.previousApp = NSWorkspace.shared.frontmostApplication
            let visibleFrame = NSRect(
                x: screenFrame.minX, y: screenFrame.minY,
                width: screenFrame.width, height: Const.defaultHeight
            )
            window.contentViewController?.view.setFrameOrigin(.zero)
            window.setFrame(visibleFrame, display: false)
            window.contentViewController?.view.layoutSubtreeIfNeeded()
        }

        // 显示窗口前安装动画，避免首帧闪现。
        animateContent(visible: true, initiallyHidden: initiallyHidden) { [weak self] in
            self?.suppressSearchFocusRing(false)
        }
        window.makeKeyAndOrderFront(nil)
    }

    @available(macOS 26.0, *)
    private func animateContent(
        visible: Bool,
        initiallyHidden: Bool = false,
        completion: @escaping @MainActor () -> Void
    ) {
        guard let view = window?.contentViewController?.view, let layer = view.layer else { return }
        suppressSearchFocusRing(true)
        slideAnimationGeneration += 1
        let generation = slideAnimationGeneration
        let key = "drawerSlide"
        let startY = initiallyHidden ? -view.bounds.height : (layer.presentation()?.transform.m42 ?? 0)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.removeAnimation(forKey: key)
        CATransaction.setCompletionBlock { [weak self] in
            Task { @MainActor in
                guard let self, generation == self.slideAnimationGeneration else { return }
                if visible {
                    self.window?.contentViewController?.view.layer?.removeAnimation(forKey: key)
                }
                completion()
            }
        }

        // 仅动画呈现位置，避免文字因实际坐标移出窗口而被裁剪。
        let animation = CABasicAnimation(keyPath: "transform.translation.y")
        animation.fromValue = startY
        animation.toValue = visible ? 0 : -view.bounds.height
        animation.duration = visible ? Const.showDuration : Const.hideDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: key)
        CATransaction.commit()
    }

    private func suppressSearchFocusRing(_ suppressed: Bool) {
        (contentViewController as? ClipMainViewController)?
            .setSearchFocusRingSuppressed(suppressed)
    }

    private func snapToPresentedPosition(_ view: NSView?) {
        guard let view else { return }
        let originY = view.layer?.presentation()?.frame.origin.y ?? view.frame.origin.y
        view.layer?.removeAllAnimations()
        view.setFrameOrigin(NSPoint(x: 0, y: originY))
    }
}

extension ClipMainWindowController: NSWindowDelegate {
    func windowDidResignKey(_: Notification) {
        guard !AppEnvironment.shared.suppressResignKey else { return }
        dismiss()
    }
}
