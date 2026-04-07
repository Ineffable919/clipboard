//
//  CategoryChipStore.swift
//  Clipboard
//
//  Created by crown on 2026/1/16.
//

import Foundation
import SwiftUI

extension Notification.Name {
    static let categoryChipsDidChange = Notification.Name("categoryChipsDidChange")
}

@MainActor
@Observable
final class CategoryChipStore {
    static let shared = CategoryChipStore()

    // MARK: - Properties

    private(set) var chips: [CategoryChip] = []
    var selectedChipId: Int = -1 {
        didSet {
            notifyChange()
        }
    }

    private let dataStore: PasteDataStore

    // MARK: - Initialization

    private init(dataStore: PasteDataStore = .main) {
        self.dataStore = dataStore
        loadCategories()
    }

    // MARK: - Public Methods

    func loadCategories() {
        chips = CategoryChip.systemChips + PasteUserDefaults.userCategoryChip
    }

    func toggleChip(_ chip: CategoryChip) {
        selectedChipId = chip.id
    }

    func selectPreviousChip() {
        guard let currentIndex = chips.firstIndex(where: { $0.id == selectedChipId }) else {
            return
        }
        let previousIndex = currentIndex > 0 ? currentIndex - 1 : chips.count - 1
        selectedChipId = chips[previousIndex].id
    }

    func selectNextChip() {
        guard let currentIndex = chips.firstIndex(where: { $0.id == selectedChipId }) else {
            return
        }
        let nextIndex = (currentIndex + 1) % chips.count
        selectedChipId = chips[nextIndex].id
    }

    func addChip(name: String, color: Color) {
        let newId = (chips.last?.id ?? 0) + 1
        let new = CategoryChip(
            id: newId,
            name: name,
            color: color,
            isSystem: false
        )
        chips.append(new)
        saveUserCategories()
    }

    func updateChip(
        _ chip: CategoryChip,
        name: String? = nil,
        color: Color? = nil
    ) {
        guard !chip.isSystem,
              let index = chips.firstIndex(where: { $0.id == chip.id })
        else {
            return
        }

        if let newName = name {
            chips[index].name = newName
        }
        if let newColor = color {
            chips[index].color = newColor
        }
        saveUserCategories()
    }

    func removeChip(_ chip: CategoryChip) {
        guard !chip.isSystem else { return }

        chips.removeAll { $0.id == chip.id }

        if selectedChipId == chip.id {
            selectedChipId = CategoryChip.systemChips.first?.id ?? -1
        }

        saveUserCategories()
        dataStore.deleteItemsByGroup(chip.id)
    }

    func getSelectedChip() -> CategoryChip? {
        chips.first { $0.id == selectedChipId }
    }

    func getGroupFilterForCurrentChip() -> Int {
        guard let chip = getSelectedChip() else { return -1 }
        return chip.isSystem ? -1 : chip.id
    }

    // MARK: - Private Methods

    private func saveUserCategories() {
        PasteUserDefaults.userCategoryChip = chips.filter { !$0.isSystem }
        dataStore.notifyCategoryChipsChanged()
        notifyChange()
    }

    private func notifyChange() {
        NotificationCenter.default.post(
            name: .categoryChipsDidChange,
            object: nil
        )
    }
}
