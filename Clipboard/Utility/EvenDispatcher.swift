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
            .keyDown,
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
    }

    func unregisterHandler(_ key: String) {
        if let idx = handlers.firstIndex(where: { $0.key == key }) {
            handlers.remove(at: idx)
        }
    }

    // MARK: - System Editing Commands

    func handleSystemEditingCommand(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }

        let keyChar = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let modifiers = event.modifierFlags.intersection([
            .command, .option, .control, .shift,
        ])

        guard modifiers.contains(.command),
              !modifiers.contains(.option),
              !modifiers.contains(.control)
        else {
            return false
        }

        let isShiftHeld = modifiers.contains(.shift)

        switch keyChar {
        case "c":
            return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
        case "v":
            return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
        case "x":
            return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
        case "a":
            return NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: nil)
        case "z":
            if isShiftHeld {
                return NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
            } else {
                return NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
            }
        default:
            return false
        }
    }

    // MARK: - Tab Navigation

    func handleTabNavigationShortcut(_ event: NSEvent, viewModel: TopBarViewModel) -> Bool {
        guard let previousTabInfo = HotKeyManager.shared.getHotKey(key: "previous_tab"),
              let nextTabInfo = HotKeyManager.shared.getHotKey(key: "next_tab")
        else {
            return false
        }

        let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let eventModifiers = event.modifierFlags.intersection(relevantModifiers)

        if previousTabInfo.isEnabled,
           event.keyCode == previousTabInfo.shortcut.keyCode,
           eventModifiers == previousTabInfo.shortcut.modifiers.intersection(relevantModifiers)
        {
            viewModel.selectPreviousChip()
            return true
        }

        if nextTabInfo.isEnabled,
           event.keyCode == nextTabInfo.shortcut.keyCode,
           eventModifiers == nextTabInfo.shortcut.modifiers.intersection(relevantModifiers)
        {
            viewModel.selectNextChip()
            return true
        }

        return false
    }

    // MARK: - Dispatching

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
                return nil
            }
        }
        return currentEvent
    }
}
