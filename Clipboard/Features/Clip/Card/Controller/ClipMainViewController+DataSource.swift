//
//  ClipMainViewController+DataSource.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import Combine

// MARK: - NSCollectionViewDelegate

extension ClipMainViewController: NSCollectionViewDelegate {
    func collectionView(_: NSCollectionView, shouldSelectItemsAt indexPaths: Set<IndexPath>) -> Set<IndexPath> {
        if let indexPath = indexPaths.first {
            resetSelectIndex(indexPath)
            // if previewPopover != nil, indexPath.item < dataList.value.count {
            //     reopenPreviewForSelectedItem()
            // }
        }
        return [selectIndexPath]
    }

    func collectionView(_: NSCollectionView, canDragItemsAt _: Set<IndexPath>, with _: NSEvent) -> Bool {
        true
    }

    func collectionView(_: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> (any NSPasteboardWriting)? {
        dataList.value[indexPath.item].writeItem
    }
}

// MARK: - Selection & Scroll

extension ClipMainViewController {
    func resetSelectIndex(
        _ indexPath: IndexPath = IndexPath(item: 0, section: 0)
    ) {
        let zero = IndexPath(item: 0, section: 0)
        if indexPath == zero, selectIndexPath == zero {
            guard !dataList.value.isEmpty else { return }
            scrollTo(indexPath: selectIndexPath)
            return
        }
        collectionView.item(at: selectIndexPath)?.isSelected = false
        selectIndexPath = indexPath
        guard !dataList.value.isEmpty else { return }
        collectionView.selectionIndexPaths = [selectIndexPath]
        scrollTo(indexPath: selectIndexPath)
        updateSelectedItemBorder()
    }

    private func event_isARepeat() -> Bool {
        guard let event = NSApp.currentEvent else { return false }

        switch event.type {
        case .keyDown:
            return event.isARepeat
        default:
            return false
        }
    }

    func scrollTo(indexPath: IndexPath) {
        guard !dataList.value.isEmpty else { return }
        guard let attrs = collectionView.layoutAttributesForItem(at: indexPath)
        else { return }

        let padding = Const.cardSpace + Const.cardSize / 5

        collectionView.scrollToVisible(
            NSRect(
                x: attrs.frame.origin.x - padding,
                y: 0,
                width: attrs.frame.width + padding * 2,
                height: attrs.frame.height
            )
        )
    }
}

// MARK: - CollectionViewItemDelegate

extension ClipMainViewController: CollectionViewItemDelegate {
    var preApp: NSRunningApplication? {
        env.previousApp
    }

    func itemDidRequestSelect(_ item: CollectionViewItem) {
        if focusRegion != .collection {
            setFocusRegion(.collection)
            view.window?.makeFirstResponder(collectionView)
        }
        guard let indexPath = collectionView.indexPath(for: item),
              indexPath != selectIndexPath else { return }
        resetSelectIndex(indexPath)
    }

    func paste(_ item: PasteboardModel) {
        ClipActionService.shared.paste(item, checkPermissions: PasteUserDefaults.pasteDirect, showTip: !PasteUserDefaults.pasteDirect)
    }

    func pastePlain(_ item: PasteboardModel) {
        ClipActionService.shared.paste(
            item,
            isAttribute: false,
            checkPermissions: PasteUserDefaults.pasteDirect,
            showTip: !PasteUserDefaults.pasteDirect
        )
    }

    func copy(_ item: PasteboardModel) {
        ClipActionService.shared.copy(item, showTip: true)
    }

    func edit(_ item: PasteboardModel) {
        EditWindowController.shared.openWindow(with: item)
    }

    func delete(_ item: PasteboardModel, indexPath: IndexPath) {
        guard PasteUserDefaults.delConfirm else {
            deleteItem(item, indexPath: indexPath)
            return
        }
    }

    func deleteItem(_ item: PasteboardModel, indexPath: IndexPath) {
        let countAfterDelete = dataList.value.count - 1
        if countAfterDelete > 0 {
            let newItem = min(indexPath.item, countAfterDelete - 1)
            selectIndexPath = IndexPath(item: newItem, section: 0)
        }

        cardVM.delete(item)
    }

    func preview(_ item: PasteboardModel) {
        if previewPopover != nil {
            closePreviewPopover()
        } else {
            guard let itemView = collectionView.item(at: selectIndexPath)?.view
            else { return }
            showPreviewPopover(for: item, relativeTo: itemView)
        }
    }
}
