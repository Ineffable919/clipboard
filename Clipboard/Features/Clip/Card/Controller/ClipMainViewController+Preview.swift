//
//  ClipMainViewController+Preview.swift
//  Clipboard
//
//  Created by crown on 2026/4/27
//

import AppKit
import Combine

extension ClipMainViewController {
    func showPreviewPopover(
        for model: PasteboardModel,
        relativeTo view: NSView
    ) {
        let rect = collectionView.convert(view.bounds, from: view)

        closePreviewPopover()
        let popover = previewPool.dequeue()
        popover.onContentInteraction = { [weak self] in
            self?.setFocusRegion(.popover)
        }
        popover.configure(with: model, maxHeight: previewHeight(for: rect))
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
        popover.show(relativeTo: rect, of: collectionView, preferredEdge: .maxY)
    }

    func retargetPreviewToSelection() {
        guard let popover = previewPopover, popover.isShown,
              let model = displayedModel(at: selectIndexPath),
              let rect = collectionView.layoutAttributesForItem(at: selectIndexPath)?.frame
        else { return }

        popover.retarget(
            to: model, relativeTo: rect, of: collectionView,
            preferredEdge: .maxY, maxHeight: previewHeight(for: rect)
        )
        if focusRegion == .popover {
            setFocusRegion(.collection)
        }
    }

    private func previewHeight(for rect: NSRect) -> CGFloat {
        guard let window = collectionView.window, let screen = window.screen
        else { return Const.maxPreviewHeight }

        let anchorOnScreen = window.convertToScreen(collectionView.convert(rect, to: nil))
        return screen.visibleFrame.maxY - anchorOnScreen.maxY
    }

    func closePreviewPopover() {
        guard let popover = previewPopover else { return }
        previewPopover = nil
        popover.close()
        if focusRegion == .popover {
            setFocusRegion(.collection)
        }
    }
}

// MARK: - NSPopoverDelegate

extension ClipMainViewController: NSPopoverDelegate {
    func popoverWillClose(_ notification: Notification) {
        guard let closing = notification.object as? ClipPreviewPopover,
              closing === previewPopover else { return }
        previewPopover = nil
        if focusRegion == .popover {
            setFocusRegion(.collection)
        }
    }
}
