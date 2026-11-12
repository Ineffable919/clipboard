//
//  ClipFloatingViewController+Preview.swift
//  Clipboard
//
//  Created by crown on 2026/5/5
//

import AppKit

extension ClipFloatingViewController {
    func togglePreview(at index: Int) {
        if previewPopover != nil {
            closePreview()
        } else {
            openPreview(at: index)
        }
    }

    func openPreview(at index: Int) {
        let historyView = floatingContentView.historyView
        guard index < historyView.dataList.count else { return }
        let model = historyView.dataList[index]
        let collection = historyView.collectionView
        let anchorView = historyView.anchorViewForItem(at: index)
        let rect = collection.convert(anchorView.bounds, from: anchorView)
        let (edge, height) = previewPlacement(for: rect)

        closePreview()
        let popover = previewPool.dequeue()
        popover.onContentInteraction = { [weak self] in
            self?.focusRegion = .popover
        }
        popover.configure(with: model, maxHeight: height)
        popover.onPinToChip = { [weak self] model, chipId in
            _ = self?.floatingContentView.topVM.assignModelToChip(model: model, chipId: chipId)
        }
        popover.onUnpin = { [weak self] model in
            _ = self?.floatingContentView.topVM.assignModelToChip(model: model, chipId: -1)
        }
        popover.onCreateChip = { [weak self] model in
            self?.closePreview()
            self?.floatingContentView.headerView.startCreatingChip(pinModel: model)
        }
        popover.delegate = self
        previewPopover = popover
        popover.show(relativeTo: rect, of: collection, preferredEdge: edge)
    }

    func retargetPreview(at index: Int) {
        let historyView = floatingContentView.historyView
        let collection = historyView.collectionView
        guard let popover = previewPopover, popover.isShown,
              historyView.dataList.indices.contains(index),
              let rect = collection.layoutAttributesForItem(at: IndexPath(item: index, section: 0))?.frame
        else { return }

        let (edge, height) = previewPlacement(for: rect)
        popover.retarget(
            to: historyView.dataList[index], relativeTo: rect, of: collection,
            preferredEdge: edge, maxHeight: height
        )
        if focusRegion == .popover {
            focusCollection()
        }
    }

    private func previewPlacement(for rect: NSRect) -> (NSRectEdge, CGFloat) {
        let collection = floatingContentView.historyView.collectionView
        guard let window = collection.window, let screen = window.screen
        else { return (.maxX, Const.maxPreviewHeight) }

        let anchorOnScreen = window.convertToScreen(collection.convert(rect, to: nil))
        let spaceRight = screen.visibleFrame.maxX - anchorOnScreen.maxX
        let spaceLeft = anchorOnScreen.minX - screen.visibleFrame.minX
        return (spaceRight >= spaceLeft ? .maxX : .minX, screen.visibleFrame.height)
    }

    func closePreview() {
        guard let popover = previewPopover else { return }
        previewPopover = nil
        popover.close()
        if focusRegion == .popover {
            focusRegion = .collection
        }
    }
}

// MARK: - NSPopoverDelegate

extension ClipFloatingViewController: NSPopoverDelegate {
    func popoverWillClose(_ notification: Notification) {
        guard let closing = notification.object as? ClipPreviewPopover,
              closing === previewPopover else { return }
        previewPopover = nil
        if focusRegion == .popover {
            focusRegion = .collection
        }
    }

    func popoverDidClose(_: Notification) {}
}
