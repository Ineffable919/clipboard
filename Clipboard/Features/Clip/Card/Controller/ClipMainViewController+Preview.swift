//
//  ClipMainViewController+Preview.swift
//  Clipboard
//
//  Created by crown on 2026/4/27.
//

import AppKit
import Combine

extension ClipMainViewController {
    func showPreviewPopover(
        for model: PasteboardModel,
        relativeTo view: NSView
    ) {
        let maxHeight: CGFloat
        if let window = view.window, let screen = window.screen {
            let anchorOnScreen = window.convertToScreen(view.convert(view.bounds, to: nil))
            maxHeight = screen.visibleFrame.maxY - anchorOnScreen.maxY
        } else {
            maxHeight = Const.maxPreviewHeight
        }

        closePreviewPopover()
        let popover = ClipPreviewPopover(model: model, maxHeight: maxHeight) { [weak self] in
            self?.setFocusRegion(.popover)
        }
        popover.onPinToChip = { [weak self] model, chipId in
            _ = self?.topVM.assignModelToChip(model: model, chipId: chipId)
        }
        popover.onUnpin = { [weak self] model in
            _ = self?.topVM.assignModelToChip(model: model, chipId: -1)
        }
        popover.onCreateChip = { [weak self] model in
            self?.closePreviewPopover()
            self?.topBarView.startCreatingChip(pinModel: model)
        }
        popover.delegate = self
        previewPopover = popover
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY)
    }

    func closePreviewPopover() {
        guard let popover = previewPopover else { return }
        previewPopover = nil
        popover.cleanup()
        popover.close()
        if focusRegion == .popover {
            setFocusRegion(.collection)
        }
    }

    func updatePreviewForSelectedItem() {
        guard selectIndexPath.item < dataList.value.count else { return }
        let model = dataList.value[selectIndexPath.item]

        if let existing = previewPopover, existing.isShown {
            existing.refreshHeader()
            return
        }

        guard let itemView = collectionView.item(at: selectIndexPath)?.view else { return }
        showPreviewPopover(for: model, relativeTo: itemView)
    }
}

// MARK: - NSPopoverDelegate

extension ClipMainViewController: NSPopoverDelegate {
    func popoverWillClose(_ notification: Notification) {
        guard let closing = notification.object as? ClipPreviewPopover,
              closing === previewPopover else { return }
        previewPopover = nil
        closing.cleanup()
        if focusRegion == .popover {
            setFocusRegion(.collection)
        }
    }
}
