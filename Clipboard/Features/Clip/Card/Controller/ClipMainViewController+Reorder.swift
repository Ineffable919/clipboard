import AppKit

extension ClipMainViewController {
    var canReorder: Bool {
        guard !draggedIDs.isEmpty, !dataStore.isReordering,
              dragFilterRevision == dataStore.filterRevision else { return false }
        let displayed = Set(diffableDataSource.snapshot().itemIdentifiers.compactMap(\.id))
        return Set(draggedIDs).isSubset(of: displayed)
    }

    func acceptReorder(at indexPath: IndexPath) -> Bool {
        guard canReorder, indexPath.section == 0 else { return false }
        let items = diffableDataSource.snapshot().itemIdentifiers
        let ids = items.compactMap(\.id)
        guard ids.count == items.count, (0 ... ids.count).contains(indexPath.item) else { return false }
        let movedIDs = draggedIDs
        let moved = Set(movedIDs)
        let before = ids.dropFirst(indexPath.item).first { !moved.contains($0) }
        let after = ids.prefix(indexPath.item).last { !moved.contains($0) }
        guard before != nil || after != nil else { return true }
        var expected = ids.filter { !moved.contains($0) }
        let destination = before.flatMap { expected.firstIndex(of: $0) } ?? expected.count
        expected.insert(contentsOf: movedIDs, at: destination)
        guard expected != ids else { return true }

        Task { [weak self] in
            guard let self else { return }
            let succeeded = await dataStore.reorderItems(movedIDs, before: before, after: after)
            if !succeeded {
                NSSound.beep()
            }
        }
        return true
    }

    func applyReorder(_ items: [PasteboardModel]) {
        let selected = Set(selectedModels.compactMap(\.id))
        let primary = displayedModel(at: selectIndexPath)?.id
        applySnapshot(items: items, animating: true) { [weak self] in
            guard let self else { return }
            let current = diffableDataSource.snapshot().itemIdentifiers
            let paths = Set(current.enumerated().compactMap { index, model -> IndexPath? in
                guard let id = model.id, selected.contains(id) else { return nil }
                return IndexPath(item: index, section: 0)
            })
            if let index = current.firstIndex(where: { $0.id == primary }) {
                selectIndexPath = IndexPath(item: index, section: 0)
            } else if let first = paths.min() {
                selectIndexPath = first
            }
            restoringSelection = true
            collectionView.selectionIndexPaths = paths
            restoringSelection = false
            updateSelectedItemBorder()
            updateQuickPasteDisplay()
            if previewPopover?.isShown == true {
                updatePreviewForSelectedItem()
            }
        }
    }
}
