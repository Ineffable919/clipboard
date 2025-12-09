//
//  EvenDispatcher.swift
//  Clipboard
//
//  Created by crown on 2025/11/29.
//

import AppKit

// MARK: - EventDispatcher

@MainActor
final class EventDispatcher {
    static let shared = EventDispatcher()
    private init() {}

    private var monitorToken: Any?

    var bypassAllEvents: Bool = false

    struct Handler {
        let key: String
        let mask: NSEvent.EventTypeMask
        let priority: Int
        let handler: (NSEvent) -> NSEvent?
    }

    private var handlers: [Handler] = []
    private var registrationOrder: [UUID] = []

    // MARK: - Lifecycle

    func start(
        matching mask: NSEvent.EventTypeMask = [
            .keyDown, .flagsChanged,
        ]
    ) {
        guard monitorToken == nil else { return }

        monitorToken = NSEvent.addLocalMonitorForEvents(matching: mask) {
            [weak self] event in
            guard let self else { return event }
            return handle(event: event)
        }

        log.debug("Global local monitor registered.")
    }

    func stop() {
        if let token = monitorToken {
            NSEvent.removeMonitor(token)
            monitorToken = nil
            log.debug("Global local monitor removed.")
        }
    }

    // MARK: - Handler registration

    func registerHandler(
        matching mask: NSEvent.EventTypeMask,
        key: String,
        priority: Int = 0,
        handler: @escaping (NSEvent) -> NSEvent?
    ) {
        unregisterHandler(key)
        let h = Handler(
            key: key,
            mask: mask,
            priority: priority,
            handler: handler
        )
        handlers.append(h)
        handlers.sort { a, b in
            a.priority > b.priority
        }
        log.debug("Registered handler \(key) priority:\(priority)")
    }

    func unregisterHandler(_ key: String) {
        if let idx = handlers.firstIndex(where: { $0.key == key }) {
            handlers.remove(at: idx)
            log.debug("Unregistered handler \(key)")
        }
    }

    // MARK: - Dispatching

    /// Core dispatch: iterate handlers; first `nil` stops chain.
    /// Propagate modified event through chain; returning nil consumes.
    private func handle(event: NSEvent) -> NSEvent? {
        // 全局开关：如果打开，所有事件都交给系统
        if bypassAllEvents {
            if event.type == .keyDown {
                let keyChar = event.charactersIgnoringModifiers?.lowercased() ?? ""
                let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])

                if modifiers.contains(.command), !modifiers.contains(.option), !modifiers.contains(.control) {
                    var handled = false

                    switch keyChar {
                    case "c":
                        handled = NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                        log.debug("Sent copy command: \(handled)")
                    case "v":
                        handled = NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                        log.debug("Sent paste command: \(handled)")
                    case "x":
                        handled = NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                        log.debug("Sent cut command: \(handled)")
                    case "a":
                        handled = NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: nil)
                        log.debug("Sent selectAll command: \(handled)")
                    case "z":
                        handled = NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                        log.debug("Sent undo command: \(handled)")
                    default:
                        break
                    }

                    if handled {
                        return nil
                    }
                }

                log.debug("Bypass all: '\(keyChar)' - returning to system")
            }
            // return event
        }

        var currentEvent = event
        for h in handlers {
            let eventMask = NSEvent.EventTypeMask(
                rawValue: 1 << currentEvent.type.rawValue
            )
            if !h.mask.contains(eventMask) { continue }
            if let next = h.handler(currentEvent) {
                currentEvent = next
            } else {
                return nil
            }
        }
        return currentEvent
    }
}
