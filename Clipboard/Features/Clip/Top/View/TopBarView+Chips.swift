//
//  TopBarView+Chips.swift
//  Clipboard
//
//  Created by crown on 2026/8/22
//
//  Chip editing and selection forwarding
//

import Foundation

extension TopBarView {
    var isEditingChip: Bool {
        topVM?.isEditingChip ?? false
    }

    func reloadChips() {
        chipController.reloadChips()
    }

    func startCreatingChip(pinModel: PasteboardModel? = nil) {
        if isSearching {
            deactivateSearch()
        }
        chipController.startCreatingChip(pinModel: pinModel)
    }

    func updateChipSelection() {
        chipController.updateChipSelection()
    }

    func commitKeyboardEditing() {
        chipController.commitKeyboardEditing()
    }

    func cancelKeyboardEditing() {
        chipController.cancelKeyboardEditing()
    }
}
