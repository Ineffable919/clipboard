//
//  ClipFloatingWindowController.swift
//  Clipboard
//
//  Created by crown on 2025/1/14.
//

import AppKit
import Combine

final class ClipFloatingWindowController: NSWindowController {
    static let shared = ClipFloatingWindowController()
    var isVisible: Bool {
        window?.isVisible ?? false
    }

    var isPinned = false

    private let clipVC = ClipFloatingViewController()
    private let db = PasteDataStore.main

    init() {
        let panel = ClipWindowView(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: FloatConst.floatWindowWidth,
                height: FloatConst.floatWindowHeight
            ),
            styleMask: [
                .nonactivatingPanel, .resizable, .closable,
                .fullSizeContentView,
            ],
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
        win.collectionBehavior = [
            .canJoinAllSpaces, .fullScreenAuxiliary, .stationary,
        ]

        win.contentView?.wantsLayer = true
        win.contentView?.layer?.cornerRadius = Const.radius
        win.contentView?.layer?.masksToBounds = true

        win.delegate = self
    }

    func configureWindowSharing() {
        guard let win = window as? ClipWindowView else { return }
        win.configureWindowSharing(
            showDuringScreenShare: PasteUserDefaults.showDuringScreenShare
        )
    }

    private func calculateWindowPosition(windowSize: NSSize) -> NSPoint {
        let windowPositionMode =
            WindowPositionMode(
                rawValue: UserDefaults.standard.integer(
                    forKey: PrefKey.windowPosition.rawValue
                )
            ) ?? .center

        switch windowPositionMode {
        case .center:
            guard let screen = NSScreen.main ?? NSScreen.screens.first else {
                return NSPoint(x: 0, y: 0)
            }
            return calculateCenterPosition(
                visibleFrame: screen.visibleFrame,
                windowSize: windowSize
            )

        case .mouse:
            return calculateMousePosition(windowSize: windowSize)

        case .lastPosition:
            guard let screen = NSScreen.main ?? NSScreen.screens.first else {
                return NSPoint(x: 0, y: 0)
            }
            return calculateLastPosition(
                visibleFrame: screen.visibleFrame,
                windowSize: windowSize
            )
        }
    }

    private func calculateCenterPosition(
        visibleFrame: NSRect,
        windowSize: NSSize
    ) -> NSPoint {
        let x = visibleFrame.midX - windowSize.width / 2
        let y = visibleFrame.midY - windowSize.height / 2
        return NSPoint(x: x, y: y)
    }

    private func calculateMousePosition(windowSize: NSSize) -> NSPoint {
        let mouseLocation = NSEvent.mouseLocation

        let screenWithMouse = NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }

        guard
            let screen = screenWithMouse ?? NSScreen.main
            ?? NSScreen.screens.first
        else {
            return mouseLocation
        }

        let visibleFrame = screen.visibleFrame

        let gap: CGFloat = 16

        // 计算鼠标在屏幕中的相对位置，决定窗口放置方向
        let mouseRelativeX =
            (mouseLocation.x - visibleFrame.minX) / visibleFrame.width
        let mouseRelativeY =
            (mouseLocation.y - visibleFrame.minY) / visibleFrame.height

        var x: CGFloat
        var y: CGFloat

        // 水平方向：鼠标在屏幕左半边则窗口放右边，反之放左边
        if mouseRelativeX < 0.5 {
            // 鼠标在左半边，窗口放鼠标右侧
            x = mouseLocation.x + gap
        } else {
            // 鼠标在右半边，窗口放鼠标左侧
            x = mouseLocation.x - windowSize.width - gap
        }

        // 垂直方向：鼠标在屏幕下半边则窗口放上边，反之放下边
        if mouseRelativeY < 0.5 {
            // 鼠标在下半边，窗口放鼠标上方
            y = mouseLocation.y + gap
        } else {
            // 鼠标在上半边，窗口放鼠标下方
            y = mouseLocation.y - windowSize.height - gap
        }

        x = max(visibleFrame.minX, min(x, visibleFrame.maxX - windowSize.width))
        y = max(
            visibleFrame.minY,
            min(y, visibleFrame.maxY - windowSize.height)
        )

        return NSPoint(x: x, y: y)
    }

    private func calculateLastPosition(visibleFrame: NSRect, windowSize: NSSize)
        -> NSPoint
    {
        guard
            let frameString = UserDefaults.standard.string(
                forKey: PrefKey.lastWindowFrame.rawValue
            )
        else {
            return calculateCenterPosition(
                visibleFrame: visibleFrame,
                windowSize: windowSize
            )
        }

        let savedFrame = NSRectFromString(frameString)

        let isValid = NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(savedFrame)
        }

        if isValid {
            return savedFrame.origin
        } else {
            // 屏幕配置改变，回退到中心模式
            return calculateCenterPosition(
                visibleFrame: visibleFrame,
                windowSize: windowSize
            )
        }
    }

    private func positionWindow() {
        guard let win = window else { return }

        let size = win.frame.size

        let finalSize: NSSize =
            if size.width < 100 || size.height < 100 {
                NSSize(
                    width: FloatConst.floatWindowWidth,
                    height: FloatConst.floatWindowHeight
                )
            } else {
                size
            }

        let origin = calculateWindowPosition(windowSize: finalSize)
        win.setFrame(NSRect(origin: origin, size: finalSize), display: true)
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
                positionWindow()
                win.orderFrontRegardless()
            }
            win.makeKey()

            clipVC.env.resetQuickPasteState()

            clipVC.setPresented(true, animated: animated, completion: nil)
        } else {
            clipVC.setPresented(false, animated: animated) { [weak self] in
                guard let self, let win = window else { return }
                win.orderOut(nil)
                completionHandler?()
                Task { [weak self] in
                    self?.db.clearExpiredData()
                }
            }
        }
    }

    private func saveWindowFrame() {
        guard let win = window else { return }
        let frame = win.frame
        UserDefaults.standard.set(
            NSStringFromRect(frame),
            forKey: PrefKey.lastWindowFrame.rawValue
        )
    }
}

extension ClipFloatingWindowController: NSWindowDelegate {
    func windowDidResignKey(_: Notification) {
        if clipVC.env.isShowDel || isPinned {
            return
        }
        setPresented(false, animated: true)
    }

    func windowDidMove(_: Notification) {
        saveWindowFrame()
    }

    func windowDidResize(_: Notification) {
        saveWindowFrame()
    }

    func windowWillClose(_: Notification) {
        saveWindowFrame()
    }
}
