//
//  CardViewModel.swift
//  Clipboard
//
//  Created by crown on 2026/4/17.
//

final class CardViewModel {
    private let pd = PasteDataStore.main

    var deleteFlag = false

    func delete(_ item: PasteboardModel) {
        guard let id = item.id else { return }

        let isInGroup = CategoryChipStore.shared.selectedChipId != -1

        if isInGroup {
            if item.hidden {
                pd.deleteItems(item)
            } else {
                pd.updateItemGroup(itemId: id, groupId: -1)
            }
        } else if item.group != -1 {
            pd.updateItemHidden(itemId: id, hidden: true)
        } else {
            pd.deleteItems(item)
        }
    }
}
