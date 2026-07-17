//
//  FilterPopover.swift
//  Clipboard
//
//  Filter Popover
//

import AppKit

final class FilterPopover: NSPopover {
    // MARK: - Properties

    var onWillClose: (() -> Void)?
    var onDidClose: (() -> Void)?

    private let filterViewController: FilterPopoverViewController
    private(set) var isClosing = false

    // MARK: - Init

    init(viewModel: TopBarViewModel) {
        filterViewController = FilterPopoverViewController(viewModel: viewModel)
        super.init()
        behavior = .transient
        contentViewController = filterViewController
        delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public API

    func toggle(relativeTo positioningRect: NSRect, of positioningView: NSView) {
        if isShown || isClosing {
            if !isClosing {
                close()
            }
            return
        }

        show(relativeTo: positioningRect, of: positioningView, preferredEdge: .maxY)

        Task { @MainActor in
            guard let window = filterViewController.view.window else { return }
            window.makeFirstResponder(filterViewController.view)
        }
    }
}

// MARK: - NSPopoverDelegate

extension FilterPopover: NSPopoverDelegate {
    func popoverWillClose(_: Notification) {
        guard !isClosing else { return }
        isClosing = true
        onWillClose?()
    }

    func popoverDidClose(_: Notification) {
        isClosing = false
        onDidClose?()
    }
}
