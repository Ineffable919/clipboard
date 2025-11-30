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
            guard let self = self else { return event }
            return self.handle(event: event)
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
        var currentEvent = event
        for h in handlers {
            let eventMask = NSEvent.EventTypeMask(
                rawValue: 1 << currentEvent.type.rawValue
            )
            if !h.mask.contains(eventMask) { continue }
            if let next = h.handler(currentEvent) {
                currentEvent = next
            } else {
                log.debug("Event consumed by handler \(h.key)")
                return nil
            }
        }
        log.debug(
            "system will handle event type:\(currentEvent.type)"
        )
        return currentEvent
    }
}
