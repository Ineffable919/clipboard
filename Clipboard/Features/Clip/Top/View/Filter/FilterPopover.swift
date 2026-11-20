//
//  FilterPopover.swift
//  Clipboard
//
//  Created by crown on 2026/4/27
//
//  Filter Popover
//

import AppKit

final class FilterPopover: NSPopover {
    // MARK: - Properties

    var onWillClose: (() -> Void)?
    var onDidClose: (() -> Void)?
    private(set) var isDisplayed = false

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
    }

    func popoverWillClose(_: Notification) {
        guard isDisplayed else { return }
        animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        isDisplayed = false
        onWillClose?()
    }

    func popoverDidClose(_: Notification) {
        onDidClose?()
    }
}
