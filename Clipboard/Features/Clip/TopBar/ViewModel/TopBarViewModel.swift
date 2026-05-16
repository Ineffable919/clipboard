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
    private var displayModeRaw: Int {
        UserDefaults.standard.integer(forKey: PrefKey.displayMode.rawValue)
    }

    // MARK: - Filter Change Publisher

    let filterDidChange = PassthroughSubject<Void, Never>()

    let clearQueryRequested = PassthroughSubject<Void, Never>()

    // MARK: - Search Properties

    private(set) var query: String = ""

    func setQuery(text: String) {
        query = text
    }

    var tags: [InputTag] = []

    // MARK: - Chip Selection

    func selectChip(id: Int) {
        CategoryChipStore.shared.selectedChipId = id
        syncGroupIdFromChipStore()
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
    private(set) var selectedTypes: Set<PasteModelType> = []

    /// 应用筛选：支持多选
    private(set) var selectedAppNames: Set<String> = []

    /// 日期筛选：单选
    private(set) var selectedDateFilter: DateFilterOption?

    /// 分组筛选：单选
    private(set) var selectedGroupId: Int?

    var hasInput: Bool {
        !query.isEmpty || !selectedTypes.isEmpty || !selectedAppNames.isEmpty
            || selectedDateFilter != nil || selectedGroupId != nil
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
        !selectedTypes.isEmpty || !selectedAppNames.isEmpty
            || selectedDateFilter != nil || selectedGroupId != nil
    }

    // MARK: - Private Properties

    private let db = PasteDataStore.main
    private let chipStore = CategoryChipStore.shared

    private var lastSearchCriteria: SearchCriteria?
    private var isModeResetting = false

    private var appPathCache: [String: String] = [:]

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
        syncGroupIdFromChipStore()
    }

    func selectPreviousChip() {
        chipStore.selectPreviousChip()
        syncGroupIdFromChipStore()
    }

    func selectNextChip() {
        chipStore.selectNextChip()
        syncGroupIdFromChipStore()
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
        syncGroupIdFromChipStore()
    }

    private func syncGroupIdFromChipStore() {
        let groupId = chipStore.getSelectChipId()
        let newGroupId = groupId == -1 ? nil : groupId
        guard selectedGroupId != newGroupId else { return }

        tags.removeAll { $0.type == .filterGroup }
        selectedGroupId = newGroupId
        if let newGroupId {
            let chipModel = chipStore.chips.first { $0.id == newGroupId }
            let label = chipModel?.name ?? ""
            let dotIcon = makeColorDotImage(
                colorIndex: chipModel?.colorIndex ?? 0
            )
            let tag = InputTag(
                icon: dotIcon,
                label: label,
                type: .filterGroup,
                associatedValue: String(newGroupId)
            )
            tags.append(tag)
        }
        filterDidChange.send()
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

    private func resetNewChipState() {
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

    private func cycleColorIndex(_ currentIndex: Int) -> Int {
        (currentIndex + 1) % CategoryChip.palette.count
    }

    // MARK: - Filter Methods

    func toggleType(_ type: PasteModelType) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
            removeTagForType(type)
        } else {
            selectedTypes.insert(type)
            addTagForType(type)
        }
        filterDidChange.send()
    }

    func toggleApp(_ appName: String, appPath: String? = nil) {
        if selectedAppNames.contains(appName) {
            selectedAppNames.remove(appName)
            tags.removeAll {
                $0.type == .filterApp && $0.associatedValue == appName
            }
        } else {
            selectedAppNames.insert(appName)
            if let path = appPath, !path.isEmpty {
                appPathCache[appName] = path
            }
            addTagForApp(appName)
        }
        filterDidChange.send()
    }

    func setDateFilter(_ option: DateFilterOption?) {
        tags.removeAll { $0.type == .filterDate }
        selectedDateFilter = option
        if let dateFilter = option {
            let tag = InputTag(
                icon: NSImage(
                    systemSymbolName: "calendar",
                    accessibilityDescription: nil
                ),
                label: dateFilter.displayName,
                type: .filterDate,
                associatedValue: dateFilter.rawValue
            )
            tags.append(tag)
        }
        filterDidChange.send()
    }

    func setGroupFilter(_ groupId: Int?) {
        tags.removeAll { $0.type == .filterGroup }
        selectedGroupId = groupId
        if let groupId {
            let chip = chipStore.chips.first { $0.id == groupId }
            let label = chip?.name ?? ""
            let dotIcon = makeColorDotImage(
                colorIndex: chip?.colorIndex ?? 0
            )
            let tag = InputTag(
                icon: dotIcon,
                label: label,
                type: .filterGroup,
                associatedValue: String(groupId)
            )
            tags.append(tag)
        }
        let chipId = groupId ?? -1
        if chipStore.selectedChipId != chipId {
            chipStore.selectedChipId = chipId
        }
        filterDidChange.send()
    }

    private func makeColorDotImage(colorIndex: Int) -> NSImage {
        let canvasSize: CGFloat = 14
        let dotSize: CGFloat = 10
        let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
        image.lockFocus()
        let color = CategoryChip.nsColor(at: colorIndex)
        color.setFill()
        let origin = (canvasSize - dotSize) / 2
        NSBezierPath(ovalIn: NSRect(x: origin, y: origin, width: dotSize, height: dotSize)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    func clearAllFilters() {
        selectedTypes.removeAll()
        selectedAppNames.removeAll()
        selectedDateFilter = nil
        selectedGroupId = nil
        tags.removeAll()
        if chipStore.selectedChipId != -1 {
            chipStore.selectedChipId = -1
        }
        filterDidChange.send()
    }

    private let textTagAssociatedValue = "text"

    private func addTagForType(_ type: PasteModelType) {
        if type == .string || type == .rich {
            let hasTextTag = tags.contains {
                $0.type == .filterType
                    && $0.associatedValue == textTagAssociatedValue
            }
            if !hasTextTag {
                let tag = InputTag(
                    icon: NSImage(
                        systemSymbolName: "doc.text",
                        accessibilityDescription: nil
                    ),
                    label: String(localized: .text),
                    type: .filterType,
                    associatedValue: textTagAssociatedValue
                )
                tags.append(tag)
            }
        } else {
            let (icon, label) = type.iconAndLabel
            let tag = InputTag(
                icon: NSImage(
                    systemSymbolName: icon,
                    accessibilityDescription: nil
                ),
                label: label,
                type: .filterType,
                associatedValue: type.rawValue
            )
            tags.append(tag)
        }
    }

    private func removeTagForType(_ type: PasteModelType) {
        if type == .string || type == .rich {
            let hasString = selectedTypes.contains(.string)
            let hasRich = selectedTypes.contains(.rich)
            if !hasString, !hasRich {
                tags.removeAll {
                    $0.type == .filterType
                        && $0.associatedValue == textTagAssociatedValue
                }
            }
        } else {
            tags.removeAll {
                $0.type == .filterType && $0.associatedValue == type.rawValue
            }
        }
    }

    private func addTagForApp(_ appName: String) {
        let appPath = appPathCache[appName] ?? ""
        let appIcon: NSImage? =
            if FileManager.default.fileExists(atPath: appPath) {
                NSWorkspace.shared.icon(forFile: appPath)
            } else {
                NSImage(
                    systemSymbolName: "questionmark.app.dashed",
                    accessibilityDescription: nil
                )
            }
        let tag = InputTag(
            icon: appIcon,
            label: appName,
            type: .filterApp,
            associatedValue: appName,
            appPath: appPath
        )
        tags.append(tag)
    }

    private var isLoadingAppPathCache = false

    func loadAppPathCache() async {
        guard !isLoadingAppPathCache, appPathCache.isEmpty else { return }
        isLoadingAppPathCache = true

        let appInfo = await PasteMetadataCache.shared.getAllAppInfo()
        await MainActor.run {
            appPathCache = Dictionary(
                uniqueKeysWithValues: appInfo.map { ($0.name, $0.path) }
            )
            isLoadingAppPathCache = false
        }
    }

    func removeTag(_ tag: InputTag) {
        tags.removeAll { $0 == tag }

        switch tag.type {
        case .filterType:
            if tag.associatedValue == textTagAssociatedValue {
                selectedTypes.remove(.string)
                selectedTypes.remove(.rich)
            } else if let type = PasteModelType(rawValue: tag.associatedValue) {
                selectedTypes.remove(type)
            }
        case .filterApp:
            selectedAppNames.remove(tag.associatedValue)
        case .filterDate:
            selectedDateFilter = nil
        case .filterGroup:
            selectedGroupId = nil
            if chipStore.selectedChipId != -1 {
                chipStore.selectedChipId = -1
            }
        }
        filterDidChange.send()
    }

    func removeLastFilter() {
        guard let lastTag = tags.last else { return }
        removeTag(lastTag)
    }

    func toggleTextType() {
        let hasString = selectedTypes.contains(.string)
        let hasRich = selectedTypes.contains(.rich)

        if hasString, hasRich {
            selectedTypes.remove(.string)
            selectedTypes.remove(.rich)
            tags.removeAll {
                $0.type == .filterType
                    && $0.associatedValue == textTagAssociatedValue
            }
        } else {
            let needAddTag = !hasString && !hasRich
            selectedTypes.insert(.string)
            selectedTypes.insert(.rich)
            if needAddTag {
                let tag = InputTag(
                    icon: NSImage(
                        systemSymbolName: "doc.text",
                        accessibilityDescription: nil
                    ),
                    label: String(localized: .text),
                    type: .filterType,
                    associatedValue: textTagAssociatedValue
                )
                tags.append(tag)
            }
        }
        filterDidChange.send()
    }

    func isTextTypeSelected() -> Bool {
        selectedTypes.contains(.string) || selectedTypes.contains(.rich)
    }

    // MARK: - Search Methods

    /// 处理查询变化，支持快捷指令（如 @img, @text 等）
    func handleQueryChange() {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)

        if trimmedQuery.hasPrefix("@"), displayModeRaw == 0 {
            let command = String(trimmedQuery.dropFirst()).lowercased()
            if let type = parseShortcutCommand(command) {
                query = ""
                clearQueryRequested.send()
                toggleType(type)
                return
            }
        }

        performSearch()
    }

    private func parseShortcutCommand(_ command: String) -> PasteModelType? {
        switch command {
        case "img", "image", "图片": .image
        case "text", "txt", "文本": .string
        case "file", "文件": .file
        case "link", "链接": .link
        case "color", "颜色": .color
        case "rich", "富文本": .rich
        default: nil
        }
    }

    func resetFilterState() {
        isModeResetting = true
        defer { isModeResetting = false }

        query = ""
        tags.removeAll()
        selectedTypes.removeAll()
        selectedAppNames.removeAll()
        selectedDateFilter = nil
        selectedGroupId = nil

        if chipStore.selectedChipId != -1 {
            chipStore.selectedChipId = -1
        }

        lastSearchCriteria = nil
    }

    func willSearchCriteriaChange() -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let criteria = SearchCriteria(
            keyword: trimmedQuery,
            selectedTypes: selectedTypes,
            selectedAppNames: selectedAppNames,
            selectedDateFilter: selectedDateFilter,
            selectedGroupId: selectedGroupId
        )
        return criteria != lastSearchCriteria
    }

    func performSearch() {
        let trimmedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let criteria = SearchCriteria(
            keyword: trimmedQuery,
            selectedTypes: selectedTypes,
            selectedAppNames: selectedAppNames,
            selectedDateFilter: selectedDateFilter,
            selectedGroupId: selectedGroupId
        )

        if criteria == lastSearchCriteria { return }
        lastSearchCriteria = criteria

        if criteria.isEmpty {
            db.resetToDefault()
        } else {
            db.searchData(criteria)
        }
    }
}

extension TopBarViewModel {
    // MARK: - Computed

    var pauseMenuTitle: String {
        guard PasteBoard.main.isPaused else { return String(localized: .pause) }
        guard let endTime = PasteBoard.main.pauseEndTime else { return String(localized: .paused) }
        return String(localized: .pauseUntil(pauseTimeString(from: endTime)))
    }

    var formattedRemainingTime: String {
        guard let endTime = PasteBoard.main.pauseEndTime else { return String(localized: .paused) }
        let remaining = max(0, endTime.timeIntervalSinceNow)
        guard remaining > 0 else { return String(localized: .paused) }
        return Duration.seconds(remaining).formatted(.time(pattern: .hourMinuteSecond))
    }

    // MARK: - Actions

    func resume() {
        PasteBoard.main.resume()
    }

    func pauseIndefinitely() {
        PasteBoard.main.pause()
    }

    func pause(for minutes: Int) {
        PasteBoard.main.pause(for: TimeInterval(minutes * 60))
    }

    // MARK: - Private

    private func pauseTimeString(from date: Date) -> String {
        date.formatted(
            .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
        )
    }
}

// MARK: - Drag & Drop

extension TopBarViewModel {
    func assignModelToChip(model: PasteboardModel, chipId: Int) -> Bool {
        if model.group == chipId {
            return true
        }

        guard let modelId = model.id else {
            return false
        }

        Task {
            await db.updateItemGroupInDB(id: modelId, groupId: chipId)
        }

        if selectedGroupId != nil {
            var list = db.dataList.value
            list.removeAll(where: { $0.id == modelId })
            db.updateData(with: list, changeType: .delete)
        } else {
            if let model = db.dataList.value.first(where: { $0.id == modelId }),
               chipId != model.group
            {
                model.updateGroup(val: chipId)
            }
            db.updateData(with: db.dataList.value, changeType: .update)
        }

        return true
    }
}
