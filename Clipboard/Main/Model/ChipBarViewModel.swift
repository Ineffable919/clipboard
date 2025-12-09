//
//  ChipBarViewModel.swift
//  Clipboard
//
//  Created by crown
//

import Foundation
import SwiftUI

@Observable
final class ChipBarViewModel {
    var chips: [CategoryChip] = []
    var selectedChipId: Int = 1

    // New Chip State
    var editingNewChip: Bool = false
    var newChipName: String = "未命名"
    var newChipColorIndex: Int = 1

    // Edit Chip State
    var editingChipId: Int?
    var editingChipName: String = ""
    var editingChipColorIndex: Int = 0

    private let dataStore: PasteDataStore

    var newChipColor: Color {
        get {
            CategoryChip.palette[newChipColorIndex % CategoryChip.palette.count]
        }
        set {
            if let index = CategoryChip.palette.firstIndex(of: newValue) {
                newChipColorIndex = index
            }
        }
    }

    var editingChipColor: Color {
        get {
            guard editingChipColorIndex >= 0,
                  editingChipColorIndex < CategoryChip.palette.count
            else {
                return .blue
            }
            return CategoryChip.palette[editingChipColorIndex]
        }
        set {
            if let index = CategoryChip.palette.firstIndex(of: newValue) {
                editingChipColorIndex = index
            }
        }
    }

    var isEditingChip: Bool {
        editingChipId != nil
    }

    var selectedChip: CategoryChip? {
        chips.first { $0.id == selectedChipId }
    }

    init(dataStore: PasteDataStore = .main) {
        self.dataStore = dataStore
        loadCategories()
    }

    // MARK: - Category Management

    private func loadCategories() {
        chips = CategoryChip.systemChips + PasteUserDefaults.userCategoryChip
    }

    private func saveUserCategories() {
        PasteUserDefaults.userCategoryChip = chips.filter { !$0.isSystem }
    }

    func toggleChip(_ chip: CategoryChip) {
        selectedChipId = chip.id
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
            selectedChipId = CategoryChip.systemChips.first?.id ?? 1
        }

        saveUserCategories()
        dataStore.deleteItemsByGroup(chip.id)
    }

    // MARK: - New Chip Methods

    func commitNewChipOrCancel(commitIfNonEmpty: Bool) {
        let trimmed = newChipName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if commitIfNonEmpty, !trimmed.isEmpty {
            addChip(name: trimmed, color: newChipColor)
        }

        resetNewChipState()
    }

    private func resetNewChipState() {
        editingNewChip = false
        newChipName = "未命名"
        newChipColorIndex = cycleColorIndex(newChipColorIndex)
    }

    // MARK: - Edit Chip Methods

    func startEditingChip(_ chip: CategoryChip) {
        guard !chip.isSystem else { return }

        editingChipId = chip.id
        editingChipName = chip.name
        editingChipColorIndex = chip.colorIndex
    }

    func commitEditingChip() {
        guard let chipId = editingChipId,
              let chip = chips.first(where: { $0.id == chipId })
        else {
            cancelEditingChip()
            return
        }

        let trimmed = editingChipName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !trimmed.isEmpty {
            updateChip(chip, name: trimmed, color: editingChipColor)
        }

        cancelEditingChip()
    }

    func cancelEditingChip() {
        editingChipId = nil
        editingChipName = ""
        editingChipColorIndex = 0
    }

    func cycleEditingChipColor() {
        editingChipColorIndex = cycleColorIndex(editingChipColorIndex)
    }

    // MARK: - Helper Methods

    private func cycleColorIndex(_ currentIndex: Int) -> Int {
        (currentIndex + 1) % CategoryChip.palette.count
    }

    func getTypeFilterForCurrentChip() -> [String]? {
        guard let chip = selectedChip else { return nil }
        return chip.typeFilter
    }

    func getGroupFilterForCurrentChip() -> Int {
        guard let chip = selectedChip else { return -1 }
        return chip.isSystem ? -1 : chip.id
    }
}
