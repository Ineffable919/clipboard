//
//  SourceAppTracker.swift
//  Clipboard
//
//  Created by crown on 2026/11/11
//

import AppKit

/// 推断剪贴板内容的来源应用
final class SourceAppTracker {
    private static let sourceType = NSPasteboard.PasteboardType("org.nspasteboard.source")
    /// 复制按键到检测到剪贴板变化的最大有效间隔
    private static let copyKeyValidity: TimeInterval = 1.5

    private var keyMonitor: Any?
    private var activationObserver: NSObjectProtocol?

    private var copyKeyApp: NSRunningApplication?
    private var copyKeyDate: Date?
    private var currentApp: NSRunningApplication?
    private var previousApp: NSRunningApplication?
    private var activatedAt: Date?

    func start() {
        stop()
        currentApp = NSWorkspace.shared.frontmostApplication

        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { self?.handleKeyDown(event) }
        }

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleActivation() }
        }
    }

    func stop() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        keyMonitor = nil
        activationObserver = nil
        copyKeyApp = nil
        copyKeyDate = nil
        currentApp = nil
        previousApp = nil
        activatedAt = nil
    }

    /// - Parameters:
    ///   - pasteboard: 已发生变化的剪贴板
    ///   - pollInterval: 轮询间隔，用于判断应用切换是否发生在本次变化窗口内
    func resolve(
        from pasteboard: NSPasteboard,
        pollInterval: TimeInterval
    ) -> NSRunningApplication? {
        defer {
            copyKeyApp = nil
            copyKeyDate = nil
        }

        if let app = declaredApp(in: pasteboard) {
            return app
        }

        let now = Date()
        if let copyKeyApp, let copyKeyDate,
           now.timeIntervalSince(copyKeyDate) <= Self.copyKeyValidity {
            return copyKeyApp
        }

        if let previousApp, let activatedAt,
           now.timeIntervalSince(activatedAt) <= pollInterval {
            return previousApp
        }

        return NSWorkspace.shared.frontmostApplication
    }

    // MARK: - Private

    /// 回调对每次全局按键都会触发，仅做最少判断
    private func handleKeyDown(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags == .command else { return }
        let key = event.charactersIgnoringModifiers?.lowercased()
        guard key == "c" || key == "x" else { return }

        copyKeyApp = NSWorkspace.shared.frontmostApplication
        copyKeyDate = Date()
    }

    private func handleActivation() {
        // 通知触发时 frontmostApplication 已是新应用，需保留切换前的应用
        previousApp = currentApp
        currentApp = NSWorkspace.shared.frontmostApplication
        activatedAt = Date()
    }

    private func declaredApp(in pasteboard: NSPasteboard) -> NSRunningApplication? {
        guard pasteboard.types?.contains(Self.sourceType) == true,
              let bundleID = pasteboard.string(forType: Self.sourceType),
              !bundleID.isEmpty
        else { return nil }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
    }
}
