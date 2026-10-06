//
//  CardViewModel.swift
//  Clipboard
//
//  Created by crown on 2026/4/17.
//

import Combine

final class CardViewModel {
    private let store = PasteDataStore.main

    func deleteMultiple(_ items: [PasteboardModel]) {
        guard !items.isEmpty else { return }
        let isInGroup = CategoryChipStore.shared.selectedChipId != -1

        var toUngroup: [PasteboardModel] = []
        var toHide: [PasteboardModel] = []
        var toPermDelete: [PasteboardModel] = []

        for item in items {
            if isInGroup {
                if item.hidden {
                    toPermDelete.append(item)
                } else {
                    toUngroup.append(item)
                }
            } else if item.group != -1 {
                toHide.append(item)
            } else {
                toPermDelete.append(item)
            }
        }

        let viewOnlyIds = Set((toUngroup + toHide).compactMap(\.id))
        if !viewOnlyIds.isEmpty {
            var list = store.dataList.value
            list.removeAll { viewOnlyIds.contains($0.id ?? -1) }
            store.updateData(with: list, changeType: .delete)

            ungroup(toUngroup)
            hide(toHide)
        }

        if !toPermDelete.isEmpty {
            store.deleteItems(toPermDelete)
        }
    }

    private func ungroup(_ items: [PasteboardModel]) {
        guard !items.isEmpty else { return }
        Task {
            for item in items {
                guard let id = item.id else { continue }
                await store.updateItemGroupInDB(id: id, groupId: -1)
            }
        }
    }

    private func hide(_ items: [PasteboardModel]) {
        for item in items {
            guard let id = item.id else { continue }
            store.updateItemHidden(itemId: id, hidden: true)
        }
    }

    func delete(_ item: PasteboardModel) {
        guard let id = item.id else { return }

        let isInGroup = CategoryChipStore.shared.selectedChipId != -1

        if isInGroup {
            if item.hidden {
                store.deleteItems(item)
            } else {
                var list = store.dataList.value
                list.removeAll(where: { $0.id == id })
                store.updateData(with: list, changeType: .delete)

                Task {
                    await store.updateItemGroupInDB(id: id, groupId: -1)
                }
            }
        } else if item.group != -1 {
            var list = store.dataList.value
            list.removeAll(where: { $0.id == id })
            store.updateData(with: list, changeType: .delete)
            store.updateItemHidden(itemId: id, hidden: true)
        } else {
            store.deleteItems(item)
        }
    }
}
