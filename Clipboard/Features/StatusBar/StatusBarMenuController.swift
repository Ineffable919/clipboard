import AppKit

@MainActor
final class StatusBarMenuController {
    private let item: NSStatusItem
    private let menu: NSMenu
    private var mouseMonitor: Any?
    private var menuObserver: CFRunLoopObserver?
    private var lastMenuClick: UInt32?

    private static var clickCount: UInt32 {
        CGEventSource.counterForEventType(.combinedSessionState, eventType: .rightMouseDown)
    }

    init(item: NSStatusItem, menu: NSMenu) {
        self.item = item
        self.menu = menu
        item.button?.sendAction(on: .leftMouseUp)
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            guard let self else { return event }
            return prepareMenu(for: event)
        }
    }

    func cleanup() {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
        if let menuObserver {
            CFRunLoopObserverInvalidate(menuObserver)
            self.menuObserver = nil
        }
    }

    private func prepareMenu(for event: NSEvent) -> NSEvent? {
        guard let window = item.button?.window, event.window === window else { return event }
        // AppKit can forward the click that just dismissed the menu back to the button.
        guard lastMenuClick != Self.clickCount else { return nil }
        // Let the original mouse-down open the native menu, without a second simulated click.
        item.menu = menu
        return event
    }

    func menuWillOpen() {
        lastMenuClick = Self.clickCount
        menuObserver = HotKeyManager.shared.observeWindowHotKey(dismissing: menu) { [weak self] event in
            guard let self, event.type == .rightMouseDown,
                  Self.clickCount != lastMenuClick,
                  let window = item.button?.window else { return false }
            // End tracking before the closing click is forwarded; don't wait for a fade-out.
            return window.frame.contains(NSEvent.mouseLocation)
        }
    }

    func menuDidClose() {
        // Remember the closing click so its forwarded action cannot reopen the menu.
        lastMenuClick = Self.clickCount
        item.menu = nil
        if let menuObserver {
            CFRunLoopObserverInvalidate(menuObserver)
            self.menuObserver = nil
        }
    }
}
