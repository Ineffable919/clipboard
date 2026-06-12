//
//  FilterPopover.swift
//  Clipboard
//
//  Filter Popover
//

import AppKit

final class FilterPopover: NSPopover {
    // MARK: - Callbacks

    var onDidClose: (() -> Void)?

    // MARK: - State

    var isShowingPopover: Bool { isShown }

    // MARK: - Init

    init(viewModel: TopBarViewModel) {
        super.init()
        behavior = .transient
        contentViewController = FilterPopoverViewController(viewModel: viewModel)
        delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Public API

    func toggle(relativeTo positioningRect: NSRect, of positioningView: NSView) {
        if isShown {
            close()
            return
        }

        show(relativeTo: positioningRect, of: positioningView, preferredEdge: .maxY)

        Task { @MainActor in
            contentViewController?.view.window?.makeFirstResponder(contentViewController?.view)
        }
    }
}

// MARK: - NSPopoverDelegate

extension FilterPopover: NSPopoverDelegate {
    func popoverDidClose(_: Notification) {
        onDidClose?()
    }
}
