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
        popover.delegate = self
        previewPopover = popover
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY)
    }

    func closePreviewPopover() {
        previewPopover?.close()
        previewPopover = nil
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
    func popoverWillClose(_: Notification) {
        if focusRegion == .popover {
            setFocusRegion(.collection)
            view.window?.makeFirstResponder(collectionView)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        // AppEnvironment.shared.previewOpen = false
        if (notification.object as? NSPopover) === previewPopover {
            previewPopover = nil
        }
    }
}
