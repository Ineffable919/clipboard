//
//  CardViewModel.swift
//  Clipboard
//
//  Created by crown on 2026/4/17.
//

import Combine

final class CardViewModel {
    private let pd = PasteDataStore.main

    func deleteMultiple(_ items: [PasteboardModel]) {
        guard !items.isEmpty else { return }
        let isInGroup = CategoryChipStore.shared.selectedChipId != -1

        var toUngroup: [PasteboardModel] = []
        var toHide: [PasteboardModel] = []
        var toPermDelete: [PasteboardModel] = []

        for item in items {
            if isInGroup {
                if item.hidden { toPermDelete.append(item) }
                else { toUngroup.append(item) }
            } else if item.group != -1 {
                toHide.append(item)
            } else {
                toPermDelete.append(item)
            }
        }

        let viewOnlyIds = Set((toUngroup + toHide).compactMap(\.id))
        if !viewOnlyIds.isEmpty {
            var list = pd.dataList.value
            list.removeAll { viewOnlyIds.contains($0.id ?? -1) }
            pd.updateData(with: list, changeType: .delete)

            if !toUngroup.isEmpty {
                Task {
                    for item in toUngroup {
                        guard let id = item.id else { continue }
                        await pd.updateItemGroupInDB(id: id, groupId: -1)
                    }
                }
            }
            for item in toHide {
                guard let id = item.id else { continue }
                pd.updateItemHidden(itemId: id, hidden: true)
            }
        }

        if !toPermDelete.isEmpty {
            pd.deleteItems(toPermDelete)
        }
    }

    func delete(_ item: PasteboardModel) {
        guard let id = item.id else { return }

        let isInGroup = CategoryChipStore.shared.selectedChipId != -1

        if isInGroup {
            if item.hidden {
                pd.deleteItems(item)
            } else {
                var list = pd.dataList.value
                list.removeAll(where: { $0.id == id })
                pd.updateData(with: list, changeType: .delete)

                Task {
                    await pd.updateItemGroupInDB(id: id, groupId: -1)
                }
            }
        } else if item.group != -1 {
            var list = pd.dataList.value
            list.removeAll(where: { $0.id == id })
            pd.updateData(with: list, changeType: .delete)
            pd.updateItemHidden(itemId: id, hidden: true)
        } else {
            pd.deleteItems(item)
        }
    }
}
