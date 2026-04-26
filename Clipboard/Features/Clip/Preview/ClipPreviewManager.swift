//
//  ClipPreviewManager.swift
//  Clipboard
//
//  管理预览 Popover 的显示、隐藏与状态
//

import AppKit

// MARK: - ClipPreviewManager

@MainActor
final class ClipPreviewManager: NSObject {
    // MARK: - Dependencies

    private var onFocusChange: ((FocusRegion) -> Void)?
    private var onPopoverClose: (() -> Void)?
    private var onRestoreFirstResponder: (() -> Void)?

    // MARK: - Popover

    private var popover: NSPopover?
    private var contentVC: ClipPreviewPopoverViewController?

    // MARK: - State

    private(set) var isShowing: Bool = false

    // MARK: - Init

    init(
        onFocusChange: @escaping (FocusRegion) -> Void,
        onPopoverClose: @escaping () -> Void,
        onRestoreFirstResponder: @escaping () -> Void
    ) {
        self.onFocusChange = onFocusChange
        self.onPopoverClose = onPopoverClose
        self.onRestoreFirstResponder = onRestoreFirstResponder
        super.init()
    }

    deinit {}

    // MARK: - Public API

    func toggle(
        for model: PasteboardModel,
        relativeTo positioningRect: NSRect,
        of view: NSView
    ) {
        if isShowing {
            close()
        } else {
            show(for: model, relativeTo: positioningRect, of: view)
        }
    }

    func show(
        for model: PasteboardModel,
        relativeTo positioningRect: NSRect,
        of view: NSView
    ) {
        guard view.window != nil else {
            return
        }

        tearDown()

        let vc = ClipPreviewPopoverViewController()
        contentVC = vc

        let p = NSPopover()
        p.behavior = .transient
        p.animates = true
        p.delegate = self
        p.contentViewController = vc
        popover = p

        _ = vc.view
        let size = vc.configure(with: model)
        p.contentSize = size

        vc.onContentInteraction = { [weak self] in
            self?.onFocusChange?(.popover)
        }
        vc.onDismiss = { [weak self] in
            self?.close()
        }

        p.show(
            relativeTo: positioningRect,
            of: view,
            preferredEdge: .maxY
        )
        isShowing = true

        onRestoreFirstResponder?()
    }

    func close() {
        guard isShowing else { return }
        isShowing = false
        popover?.close()
    }

    // MARK: - Private

    private func tearDown() {
        contentVC?.cleanup()
        popover?.delegate = nil
        popover?.close()
        popover = nil
        contentVC = nil
        isShowing = false
    }
}

// MARK: - NSPopoverDelegate

extension ClipPreviewManager: NSPopoverDelegate {
    func popoverDidClose(_: Notification) {
        tearDown()
        onPopoverClose?()
    }
}
