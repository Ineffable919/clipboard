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
        closePreviewPopover()
        let popover = ClipPreviewPopover(model: model) {
            self.setFocusRegion(.popover)
        }
        popover.onPinToChip = { [weak self] model, chipId in
            _ = self?.topVM.assignModelToChip(model: model, chipId: chipId)
        }
        popover.onUnpin = { [weak self] model in
            _ = self?.topVM.assignModelToChip(model: model, chipId: -1)
        }
        popover.delegate = self
        previewPopover = popover
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY)
    }

    func closePreviewPopover() {
        guard let popover = previewPopover else { return }
        popover.onContentInteraction = nil
        previewPopover = nil
        popover.close()
        if focusRegion == .popover {
            setFocusRegion(.collection)
        }
    }

    func reopenPreviewForSelectedItem() {
        guard selectIndexPath.item < dataList.value.count,
              let itemView = collectionView.item(at: selectIndexPath)?.view
        else { return }
        let model = dataList.value[selectIndexPath.item]
        showPreviewPopover(for: model, relativeTo: itemView)
    }
}

// MARK: - NSPopoverDelegate

extension ClipMainViewController: NSPopoverDelegate {
    func popoverWillClose(_ notification: Notification) {
        guard let closing = notification.object as? ClipPreviewPopover,
              closing === previewPopover else { return }
        closing.onContentInteraction = nil
        previewPopover = nil
        if focusRegion == .popover {
            setFocusRegion(.collection)
            view.window?.makeFirstResponder(collectionView)
        }
    }

    func popoverDidClose(_: Notification) {}
}
