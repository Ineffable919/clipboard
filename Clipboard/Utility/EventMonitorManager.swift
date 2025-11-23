//
//  EventMonitorManager.swift
//  Clipboard
//
//  Created by crown on 2025/11/23.
//

import AppKit
import Foundation

class EventMonitorManager {
    static let shared = EventMonitorManager()

    private init() {}

    enum MonitorType {
        case globalSettings
        case settingWindow
        case historyArea
        case historyFlags
        case shortcutRecorder

        var priority: Int {
            switch self {
            case .shortcutRecorder: 100
            case .historyArea: 80
            case .historyFlags: 70
            case .settingWindow: 50
            case .globalSettings: 30
            }
        }

        var identifier: String {
            switch self {
            case .globalSettings: "app.global.settings"
            case .settingWindow: "window.settings"
            case .historyArea: "view.history.keyboard"
            case .historyFlags: "view.history.flags"
            case .shortcutRecorder: "view.shortcut.recorder"
            }
        }
    }

    private struct MonitorInfo {
        let monitor: Any
        let type: MonitorType
        let addedAt: Date
    }

    private var monitors: [String: MonitorInfo] = [:]
    private let lock = NSLock()

    /// 注册本地事件监听器
    /// - Parameters:
    ///   - type: 监听器类型
    ///   - mask: 要监听的事件类型
    ///   - handler: 事件处理闭包
    @discardableResult
    func addLocalMonitor(
        type: MonitorType,
        matching mask: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> NSEvent?,
    ) -> Any? {
        lock.lock()
        defer { lock.unlock() }

        let identifier = type.identifier

        if let existing = monitors[identifier] {
            NSEvent.removeMonitor(existing.monitor)
            monitors.removeValue(forKey: identifier)
        }

        let monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler)

        if let monitor {
            monitors[identifier] = MonitorInfo(
                monitor: monitor,
                type: type,
                addedAt: Date(),
            )
        }

        return monitor
    }

    func removeMonitor(type: MonitorType) {
        lock.lock()
        defer { lock.unlock() }

        let identifier = type.identifier
        if let info = monitors[identifier] {
            NSEvent.removeMonitor(info.monitor)
            monitors.removeValue(forKey: identifier)
        }
    }

    func removeAllMonitors() {
        lock.lock()
        defer { lock.unlock() }

        for (_, info) in monitors {
            NSEvent.removeMonitor(info.monitor)
        }
        monitors.removeAll()
    }

    func debugPrintActiveMonitors() {
        lock.lock()
        defer { lock.unlock() }

        log.debug("📊 当前活跃的事件监听器（共 \(monitors.count) 个）：")
        let sorted = monitors.values.sorted { $0.type.priority > $1.type.priority }
        for info in sorted {
            let duration = Date().timeIntervalSince(info.addedAt)
            log.debug("  - [\(info.type.priority)] \(info.type.identifier) (已存活 \(String(format: "%.1f", duration))s)")
        }
    }
}
