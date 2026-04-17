//
//  ClipMainViewController+DataSource.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import Combine

// MARK: - NSCollectionViewDataSource

extension ClipMainViewController: NSCollectionViewDataSource {
    func numberOfSections(in _: NSCollectionView) -> Int {
        1
    }

    func collectionView(_: NSCollectionView, numberOfItemsInSection _: Int) -> Int {
        dataList.value.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: CollectionViewItem.identifier,
            for: indexPath
        )
        guard let cItem = item as? CollectionViewItem else { return item }
        let model = dataList.value[indexPath.item]
        cItem.delegate = self
        cItem.configure(with: model, keyword: topVM.query)
        if selectIndexPath == indexPath {
            cItem.isSelected = true
            cItem.setFocused(focusRegion == .collection)
            collectionView.selectionIndexPaths = [indexPath]
        } else {
            cItem.isSelected = false
        }
        return cItem
    }
}

// MARK: - NSCollectionViewDelegate

extension ClipMainViewController: NSCollectionViewDelegate {
    func collectionView(_: NSCollectionView, shouldSelectItemsAt indexPaths: Set<IndexPath>) -> Set<IndexPath> {
        if let indexPath = indexPaths.first {
            resetSelectIndex(indexPath)
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

    private func scrollTo(indexPath: IndexPath) {
        guard !dataList.value.isEmpty else { return }
        guard let attrs = collectionView.layoutAttributesForItem(at: indexPath)
        else { return }
        collectionView.scrollToVisible(
            NSRect(
                x: attrs.frame.origin.x - Const.cardSpace,
                y: 0,
                width: attrs.frame.width + Const.cardSpace * 2 + Const.cardSize / 5,
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
        if ClipActionService.shared.paste(item, checkPermissions: PasteUserDefaults.pasteDirect) {
            resetSelectIndex()
        }
    }

    func pastePlain(_ item: PasteboardModel) {
        if ClipActionService.shared.paste(
            item,
            isAttribute: false,
            checkPermissions: PasteUserDefaults.pasteDirect
        ) {
            resetSelectIndex()
        }
    }

    func copy(_ item: PasteboardModel) {
        ClipActionService.shared.copy(item)
        resetSelectIndex()
    }

    func edit(_ item: PasteboardModel) {
        EditWindowController.shared.openWindow(with: item)
    }

    func delete(_ item: PasteboardModel, indexPath: IndexPath) {
        defer { deleteFlag = false }
        deleteFlag = true
        guard PasteUserDefaults.delConfirm else {
            deleteItem(item, indexPath: indexPath)
            return
        }
    }

    func deleteItem(_ item: PasteboardModel, indexPath: IndexPath) {
        PasteDataStore.main.deleteItems(item)
        collectionView.animator().deleteItems(at: [indexPath])

        let newCount = dataList.value.count
        if newCount > 0 {
            let newItem = min(indexPath.item, newCount - 1)
            let newIndexPath = IndexPath(item: newItem, section: 0)
            selectIndexPath = IndexPath(item: -1, section: 0)
            resetSelectIndex(newIndexPath)
        }
    }

    func preview(_: PasteboardModel) {
        // TODO: show preview popover
    }
}
