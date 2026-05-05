//
//  ClipFloatingViewController+Preview.swift
//  Clipboard
//
//  Created by crown on 2026/5/5.
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
        let anchorView = historyView.anchorViewForItem(at: index)

        closePreview()
        let popover = ClipPreviewPopover(model: model) { [weak self] in
            self?.focusRegion = .popover
        }
        popover.delegate = self
        previewPopover = popover
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .maxX)
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
