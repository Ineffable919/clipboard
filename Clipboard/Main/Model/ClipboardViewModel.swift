//
//  ClipboardViewModel.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import KeyboardShortcuts
import Observation
import SwiftUI

@Observable
final class ClipboardViewModel {
    static let shard = ClipboardViewModel()

    // MARK: - Search State

    var isSearching: Bool = false
    var query: String = ""

    // MARK: - UI State

    var isShowDel: Bool = false
    var focusView: FocusField = .history

    // MARK: - Chip Management

    var chips: [CategoryChip] = []
    var selectedChipId: Int = 1

    // MARK: - New Chip State

    var editingNewChip: Bool = false
    var newChipName: String = "未命名"
    var newChipColorIndex: Int = 1

    // MARK: - Edit Chip State

    var editingChipId: Int?
    var editingChipName: String = ""
    var editingChipColorIndex: Int = 0

    // MARK: - Computed Properties

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

    // MARK: - Private Properties

    private let pd = PasteDataStore.main
    private var searchTask: Task<Void, Never>?

    private var lastQuery: String = ""
    private var lastTypeFilter: [String]?
    private var lastGroup: Int = -1

    // MARK: - Initialization

    init() {
        loadCategories()
    }

    // MARK: - Search Methods

    func onSearchParametersChanged() {
        searchTask?.cancel()

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

            guard !Task.isCancelled else { return }
            await searchClipboards()
        }
    }

    private func searchClipboards() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let typeFilter = getTypeFilterForCurrentChip()
        let group = getGroupFilterForCurrentChip()

        if trimmedQuery == lastQuery,
           typeFilter == lastTypeFilter,
           group == lastGroup
        {
            return
        }

        if trimmedQuery.isEmpty, selectedChipId == 1 {
            pd.resetDefaultList()
            isSearching = false
        } else {
            pd.searchData(trimmedQuery, typeFilter, group)
            isSearching = true
        }

        lastQuery = trimmedQuery
        lastTypeFilter = typeFilter
        lastGroup = group
    }

    private func getTypeFilterForCurrentChip() -> [String]? {
        guard let chip = selectedChip else { return nil }

        return chip.typeFilter
    }

    private func getGroupFilterForCurrentChip() -> Int {
        guard let chip = selectedChip else { return -1 }
        return chip.isSystem ? -1 : chip.id
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
            isSystem: false,
        )
        chips.append(new)
        saveUserCategories()
    }

    func updateChip(
        _ chip: CategoryChip,
        name: String? = nil,
        color: Color? = nil,
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

        pd.deleteItemsByGroup(chip.id)
    }

    // MARK: - New Chip Methods

    func commitNewChipOrCancel(commitIfNonEmpty: Bool) {
        let trimmed = newChipName.trimmingCharacters(
            in: .whitespacesAndNewlines,
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
            in: .whitespacesAndNewlines,
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

    /// 循环颜色索引，跳过 gray（索引 0）
    private func cycleColorIndex(_ currentIndex: Int) -> Int {
        var nextIndex = (currentIndex + 1) % CategoryChip.palette.count
        if nextIndex == 0 {
            nextIndex = 1
        }
        return nextIndex
    }
}

extension ClipboardViewModel {
    func pasteAction(item: PasteboardModel, isAttribute: Bool = true) {
        let temp = isSearching
        if temp {
            isSearching = false
        }
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.isSearching = temp
            }
        }
        PasteBoard.main.pasteData(item, isAttribute)
        guard PasteUserDefaults.pasteDirect else { return }
        ClipMainWindowController.shared.toggleWindow {
            KeyboardShortcuts.postCmdVEvent()
        }
    }

    func copyAction(item: PasteboardModel, isAttribute: Bool = true) {
        PasteBoard.main.pasteData(item, isAttribute)
    }

    func deleteAction(item: PasteboardModel) {
        PasteDataStore.main.deleteItems(item)
    }
}

enum FocusField: Hashable {
    case search
    case newChip
    case editChip
    case history
    case popover
}
