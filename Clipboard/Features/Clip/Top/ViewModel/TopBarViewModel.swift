//
//  TopBarViewModel.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit
import Combine
import Foundation
import SQLite

final class TopBarViewModel {
    var displayModeRaw: Int {
        UserDefaults.standard.integer(forKey: PrefKey.displayMode.rawValue)
    }

    // MARK: - Filter Change Publisher

    let filterDidChange = PassthroughSubject<Void, Never>()

    let clearQueryRequested = PassthroughSubject<Void, Never>()

    // MARK: - Search Properties

    var query: String = ""
    let textTagAssociatedValue = "text"

    func setQuery(text: String) {
        query = text
    }

    var tags: [InputTag] = []

    // MARK: - Chip Selection

    func selectChip(id: Int) {
        CategoryChipStore.shared.selectedChipId = id
        syncGroupIdsFromChipStore()
    }

    // New Chip State
    var editingNewChip: Bool = false
    var newChipName: String = .init(localized: .untitled)
    var newChipColorIndex: Int = 1
    var pendingPinModel: PasteboardModel?

    // Edit Chip State
    var editingChipId: Int?
    var editingChipName: String = ""
    var editingChipColorIndex: Int = 0

    // MARK: - Filter Properties

    /// 类型筛选：支持多选
    var selectedTypes: Set<PasteModelType> = []

    /// 应用筛选：支持多选
    var selectedAppIDs: Set<Int64> = []

    /// 日期筛选：单选
    var selectedDateFilter: DateFilterOption?

    /// 分组筛选：支持多选
    var selectedGroupIds: Set<Int> = []

    var hasInput: Bool {
        !query.isEmpty || !selectedTypes.isEmpty || !selectedAppIDs.isEmpty
            || selectedDateFilter != nil || !selectedGroupIds.isEmpty
    }

    func clearInput() {
        guard hasInput else { return }
        query = ""
        clearAllFilters()
    }

    var isEditingChip: Bool {
        editingChipId != nil
    }

    var hasActiveFilters: Bool {
        !selectedTypes.isEmpty || !selectedAppIDs.isEmpty
            || selectedDateFilter != nil || !selectedGroupIds.isEmpty
    }

    // MARK: - Private Properties

    let store = PasteDataStore.main
    let chipStore = CategoryChipStore.shared

    var lastSearchCriteria: SearchCriteria?
    var isModeResetting = false

    // MARK: - Initialization

    init() {
        query = ""
    }

    // MARK: - Category Management

    func chips() -> [CategoryChip] {
        chipStore.chips
    }

    func getSelectChipId() -> Int {
        chipStore.selectedChipId
    }

    func setSelectChipId(chip: Int) {
        chipStore.selectedChipId = chip
        syncGroupIdsFromChipStore()
    }

    func selectPreviousChip() {
        chipStore.selectPreviousChip()
        syncGroupIdsFromChipStore()
    }

    func selectNextChip() {
        chipStore.selectNextChip()
        syncGroupIdsFromChipStore()
    }

    func addChip(name: String, colorIndex: Int) {
        chipStore.addChip(name: name, colorIndex: colorIndex)
    }

    func updateChip(
        _ chip: CategoryChip,
        name: String? = nil,
        colorIndex: Int? = nil
    ) {
        chipStore.updateChip(chip, name: name, colorIndex: colorIndex)
    }

    func removeChip(_ chip: CategoryChip) {
        chipStore.removeChip(chip)
        selectedGroupIds.remove(chip.id)
        refreshGroupTags()
    }

    func syncGroupIdsFromChipStore() {
        let groupId = chipStore.getSelectChipId()
        let newGroupIds: Set<Int> = groupId == -1 ? [] : [groupId]
        guard selectedGroupIds != newGroupIds else { return }

        selectedGroupIds = newGroupIds
        refreshGroupTags()
    }

    // MARK: - New Chip Methods

    func commitNewChipOrCancel(commitIfNonEmpty: Bool) {
        let trimmed = newChipName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let colorIndex = newChipColorIndex
        let pinTarget = pendingPinModel
        pendingPinModel = nil
        resetNewChipState()
        if commitIfNonEmpty, !trimmed.isEmpty {
            addChip(name: trimmed, colorIndex: colorIndex)
            if let pinTarget, let newChipId = chipStore.chips.last?.id {
                _ = assignModelToChip(model: pinTarget, chipId: newChipId)
            }
        }
    }

    func resetNewChipState() {
        editingNewChip = false
        newChipName = String(localized: .untitled)
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
              let chip = chipStore.chips.first(where: { $0.id == chipId })
        else {
            cancelEditingChip()
            return
        }
        editingChipId = nil
        let trimmed = editingChipName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !trimmed.isEmpty {
            updateChip(chip, name: trimmed, colorIndex: editingChipColorIndex)
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

    func cycleColorIndex(_ currentIndex: Int) -> Int {
        (currentIndex + 1) % CategoryChip.palette.count
    }

}
