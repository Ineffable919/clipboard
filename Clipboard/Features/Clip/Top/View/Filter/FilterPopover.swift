//
//  FilterPopover.swift
//  Clipboard
//
//  Filter Popover
//

import AppKit

final class FilterPopover: NSPopover {
    // MARK: - Properties

    var onWillShow: (() -> Void)?
    var onWillClose: (() -> Void)?
    private(set) var isDisplayed = false
    private var closingWindow: NSWindow?

    private let controller: FilterPopoverViewController

    // MARK: - Init

    init(viewController: FilterPopoverViewController) {
        controller = viewController
        super.init()
        behavior = .transient
        contentViewController = controller
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    isolated deinit {
        if let closingWindow {
            Task { @MainActor in
                withExtendedLifetime(closingWindow) {}
            }
        }
    }

    // MARK: - Public API

    func prepare() {
        controller.prepare()
    }

    func toggle(relativeTo positioningRect: NSRect, of positioningView: NSView) {
        if isDisplayed {
            close()
            return
        }

        animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        show(relativeTo: positioningRect, of: positioningView, preferredEdge: .maxY)
        animates = false

        guard isDisplayed, let window = controller.view.window else { return }
        window.initialFirstResponder = controller.view
        window.makeFirstResponder(controller.view)
    }
}

// MARK: - NSPopoverDelegate

extension FilterPopover: NSPopoverDelegate {
    func popoverWillShow(_: Notification) {
        isDisplayed = true
        onWillShow?()
    }

    func popoverWillClose(_: Notification) {
        guard isDisplayed else { return }
        closingWindow = controller.view.window
        animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        isDisplayed = false
        contentViewController = nil
        onWillClose?()
    }
}
