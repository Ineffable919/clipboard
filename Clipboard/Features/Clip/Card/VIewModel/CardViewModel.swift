//
//  CardViewModel.swift
//  Clipboard
//
//  Created by crown on 2026/4/17.
//

import Combine

final class CardViewModel {
    private let pd = PasteDataStore.main

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
