//
//  FloatingHistoryView+Drag.swift
//  Clipboard
//
//  Created by crown on 2026/10/2
//

import AppKit

// MARK: - Drag

extension FloatingHistoryView {
    func handleDragMoved(_ screenPoint: NSPoint) {
        guard let window else { return }
        let visibleRect = convert(bounds, to: nil)
        let screenRect = window.convertToScreen(visibleRect)
        if !screenRect.contains(screenPoint),
           ClipFloatingWindowController.shared.isVisible {
            ClipFloatingWindowController.shared.toggleWindow()
        }
    }

    func handleDragEnded(_ screenPoint: NSPoint) {
        guard let window else { return }
        let visibleRect = convert(bounds, to: nil)
        let screenRect = window.convertToScreen(visibleRect)
        // 拖离浮窗后窗口已收起，此时不能再让它抢回键盘焦点
        guard ClipFloatingWindowController.shared.isVisible,
              screenRect.contains(screenPoint)
        else { return }

        env.suppressResignKey = true
        window.resignKey()
        window.makeKey()
        window.makeFirstResponder(collectionView)
        env.suppressResignKey = false
    }
}

// MARK: - Drag & Drop Delegate

extension FloatingHistoryView {
    func collectionView(
        _: NSCollectionView,
        canDragItemsAt _: Set<IndexPath>,
        with _: NSEvent
    ) -> Bool {
        true
    }

    func collectionView(
        _: NSCollectionView,
        pasteboardWriterForItemAt indexPath: IndexPath
    ) -> (any NSPasteboardWriting)? {
        guard indexPath.item < dataList.count else { return nil }
        return dataList[indexPath.item].writeItem
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        draggingSession session: NSDraggingSession, willBeginAt _: NSPoint,
        forItemsAt indexPaths: Set<IndexPath>
    ) {
        for indexPath in indexPaths { collectionView.item(at: indexPath)?.view.isHidden = false }
        let extraURLs = indexPaths.sorted()
            .filter { $0.item < dataList.count }
            .flatMap { dataList[$0.item].extraDragFileURLs }
        if !extraURLs.isEmpty {
            session.draggingPasteboard.writeObjects(extraURLs)
        }
    }

    func collectionView(
        _: NSCollectionView,
        validateDrop draggingInfo: any NSDraggingInfo,
        proposedIndexPath _: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
        dropOperation _: UnsafeMutablePointer<NSCollectionView.DropOperation>
    ) -> NSDragOperation {
        guard !(draggingInfo.draggingSource is NSCollectionView) else { return [] }
        let pasteboard = draggingInfo.draggingPasteboard
        guard pasteboard.canReadItem(withDataConformingToTypes: Self.dropSupportedTypes) else { return [] }
        dragSourceApp = NSWorkspace.shared.frontmostApplication
        return .copy
    }

    func collectionView(
        _: NSCollectionView,
        acceptDrop draggingInfo: any NSDraggingInfo,
        indexPath _: IndexPath,
        dropOperation _: NSCollectionView.DropOperation
    ) -> Bool {
        let accepted = dataStore.addNewItem(
            draggingInfo.draggingPasteboard,
            sourceApp: dragSourceApp,
            chipId: CategoryChipStore.shared.selectedChipId
        )
        dragSourceApp = nil
        return accepted
    }

    private static let dropSupportedTypes = PasteboardType.supportTypes.map(\.rawValue)
}
