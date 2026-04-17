//
//  CategoryChipStore.swift
//  Clipboard
//
//  Created by crown on 2026/1/16.
//

import Combine
import Foundation

extension Notification.Name {
    static let categoryChipsDidChange = Notification.Name("categoryChipsDidChange")
}

final class CategoryChipStore {
    static let shared = CategoryChipStore()

    // MARK: - Properties

    private(set) var chips: [CategoryChip] = []
    @Published var selectedChipId: Int = -1 {
        didSet {
            notifyChange()
        }
    }

    let chipsContentDidChange = PassthroughSubject<Void, Never>()

    private let db = PasteDataStore.main

    // MARK: - Initialization

    private init() {
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

    func addChip(name: String, colorIndex: Int) {
        let newId = (chips.last?.id ?? 0) + 1
        let new = CategoryChip(
            id: newId,
            name: name,
            colorIndex: colorIndex,
            isSystem: false
        )
        chips.append(new)
        saveUserCategories()
    }

    func updateChip(
        _ chip: CategoryChip,
        name: String? = nil,
        colorIndex: Int? = nil
    ) {
        guard !chip.isSystem,
              let index = chips.firstIndex(where: { $0.id == chip.id })
        else {
            return
        }

        if let newName = name {
            chips[index].name = newName
        }
        if let newColorIndex = colorIndex {
            chips[index].colorIndex = newColorIndex
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
        db.deleteItemsByGroup(chip.id)
    }

    func getSelectedChip() -> CategoryChip? {
        chips.first { $0.id == selectedChipId }
    }

    func getSelectChipId() -> Int {
        guard let chip = getSelectedChip() else { return -1 }
        return chip.isSystem ? -1 : chip.id
    }

    // MARK: - Private Methods

    private func saveUserCategories() {
        PasteUserDefaults.userCategoryChip = chips.filter { !$0.isSystem }
        db.notifyCategoryChipsChanged()
        chipsContentDidChange.send()
        //notifyChange()
    }

    private func notifyChange() {
        NotificationCenter.default.post(
            name: .categoryChipsDidChange,
            object: nil
        )
    }
}
