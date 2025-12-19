//
//  TopBarViewModel.swift
//  Clipboard
//
//  Created by crown
//

import Foundation
import SQLite
import SwiftUI

@Observable
@MainActor
final class TopBarViewModel {
    // MARK: - Search Properties

    var query: String = "" {
        didSet {
            performSearch()
        }
    }

    var tags: [InputTag] = []

    // MARK: - Chip Properties

    var chips: [CategoryChip] = []
    var selectedChipId: Int = 1 {
        didSet {
            performSearch()
        }
    }

    // New Chip State
    var editingNewChip: Bool = false
    var newChipName: String = "未命名"
    var newChipColorIndex: Int = 1

    // Edit Chip State
    var editingChipId: Int?
    var editingChipName: String = ""
    var editingChipColorIndex: Int = 0

    // MARK: - Filter Properties

    // 类型筛选：支持多选
    private(set) var selectedTypes: Set<PasteModelType> = []

    // 应用筛选：支持多选
    private(set) var selectedAppNames: Set<String> = []

    // 日期筛选：单选
    private(set) var selectedDateFilter: DateFilterOption?

    // 分类筛选：支持多选
    var selectedCategoryIds: Set<Int> = [] {
        didSet {
            performSearch()
        }
    }

    var hasInput: Bool {
        !query.isEmpty || !selectedTypes.isEmpty || !selectedAppNames.isEmpty
            || selectedDateFilter != nil
    }

    func clearInput() {
        query = ""
        clearAllFilters()
    }

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

    var hasActiveFilters: Bool {
        !selectedTypes.isEmpty || !selectedAppNames.isEmpty
            || selectedDateFilter != nil || !selectedCategoryIds.isEmpty
    }

    // MARK: - Private Properties

    private let dataStore: PasteDataStore
    private var searchTask: Task<Void, Never>?

    private var lastCriteria: PasteDataStore.SearchCriteria = .empty

    private var appPathCache: [String: String] = [:]

    // MARK: - DateFilterOption

    enum DateFilterOption: String, CaseIterable {
        case today = "Today"
        case yesterday = "Yesterday"
        case thisWeek = "This week"
        case lastWeek = "Last week"
        case thisMonth = "This month"

        var displayName: String {
            switch self {
            case .today: "今天"
            case .yesterday: "昨天"
            case .thisWeek: "本周"
            case .lastWeek: "上周"
            case .thisMonth: "近一个月"
            }
        }

        func timestampRange() -> (start: Int64, end: Int64?) {
            let calendar = Calendar.current
            let now = Date()

            switch self {
            case .today:
                let startOfDay = calendar.startOfDay(for: now)
                let startTimestamp = Int64(startOfDay.timeIntervalSince1970)
                return (startTimestamp, nil)

            case .yesterday:
                let yesterday =
                    calendar.date(byAdding: .day, value: -1, to: now) ?? now
                let startOfYesterday = calendar.startOfDay(for: yesterday)
                let endOfYesterday =
                    calendar.date(
                        byAdding: .day,
                        value: 1,
                        to: startOfYesterday
                    ) ?? now
                let startTimestamp = Int64(
                    startOfYesterday.timeIntervalSince1970
                )
                let endTimestamp = Int64(endOfYesterday.timeIntervalSince1970)
                return (startTimestamp, endTimestamp)

            case .thisWeek:
                let startOfWeek =
                    calendar.date(
                        from: calendar.dateComponents(
                            [.yearForWeekOfYear, .weekOfYear],
                            from: now
                        )
                    ) ?? now
                let startTimestamp = Int64(startOfWeek.timeIntervalSince1970)
                return (startTimestamp, nil)

            case .lastWeek:
                let thisWeekStart =
                    calendar.date(
                        from: calendar.dateComponents(
                            [.yearForWeekOfYear, .weekOfYear],
                            from: now
                        )
                    ) ?? now
                let lastWeekStart =
                    calendar.date(
                        byAdding: .weekOfYear,
                        value: -1,
                        to: thisWeekStart
                    ) ?? now
                let endOfLastWeek = thisWeekStart
                let startTimestamp = Int64(lastWeekStart.timeIntervalSince1970)
                let endTimestamp = Int64(endOfLastWeek.timeIntervalSince1970)
                return (startTimestamp, endTimestamp)

            case .thisMonth:
                let startOfMonth =
                    calendar.date(
                        from: calendar.dateComponents(
                            [.year, .month],
                            from: now
                        )
                    ) ?? now
                let startTimestamp = Int64(startOfMonth.timeIntervalSince1970)
                return (startTimestamp, nil)
            }
        }
    }

    // MARK: - Initialization

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

    func getGroupFilterForCurrentChip() -> Int {
        guard let chip = selectedChip else { return -1 }
        return chip.isSystem ? -1 : chip.id
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
        performSearch()
    }

    func toggleApp(_ appName: String) {
        if selectedAppNames.contains(appName) {
            selectedAppNames.remove(appName)
            tags.removeAll { $0.type == .filterApp && $0.associatedValue == appName }
        } else {
            selectedAppNames.insert(appName)
            addTagForApp(appName)
        }
        performSearch()
    }

    func setDateFilter(_ option: DateFilterOption?) {
        tags.removeAll { $0.type == .filterDate }
        selectedDateFilter = option
        if let dateFilter = option {
            let tag = InputTag(
                icon: AnyView(Image(systemName: "calendar")),
                label: dateFilter.displayName,
                type: .filterDate,
                associatedValue: dateFilter.rawValue
            )
            tags.append(tag)
        }
        performSearch()
    }

    func toggleCategory(_ categoryId: Int) {
        if selectedCategoryIds.contains(categoryId) {
            selectedCategoryIds.remove(categoryId)
        } else {
            selectedCategoryIds.insert(categoryId)
        }
    }

    func clearAllFilters() {
        selectedTypes.removeAll()
        selectedAppNames.removeAll()
        selectedDateFilter = nil
        selectedCategoryIds.removeAll()
        tags.removeAll()
    }

    // MARK: - Tags Management
    private let textTagAssociatedValue = "text"

    private func addTagForType(_ type: PasteModelType) {
        if type == .string || type == .rich {
            let hasTextTag = tags.contains {
                $0.type == .filterType && $0.associatedValue == textTagAssociatedValue
            }
            if !hasTextTag {
                let tag = InputTag(
                    icon: AnyView(Image(systemName: "text.document")),
                    label: "文本",
                    type: .filterType,
                    associatedValue: textTagAssociatedValue
                )
                tags.append(tag)
            }
        } else {
            let (icon, label) = type.iconAndLabel
            let tag = InputTag(
                icon: AnyView(Image(systemName: icon)),
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
                    $0.type == .filterType && $0.associatedValue == textTagAssociatedValue
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
        let appIcon: AnyView
        if FileManager.default.fileExists(atPath: appPath) {
            appIcon = AnyView(
                Image(nsImage: NSWorkspace.shared.icon(forFile: appPath))
                    .resizable()
                    .scaledToFit()
            )
        } else {
            appIcon = AnyView(Image(systemName: "app.fill"))
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

    func loadAppPathCache() async {
        let appInfo = await dataStore.getAllAppInfo()
        await MainActor.run {
            appPathCache = Dictionary(
                uniqueKeysWithValues: appInfo.map { ($0.name, $0.path) }
            )
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
        }
        performSearch()
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
                $0.type == .filterType && $0.associatedValue == textTagAssociatedValue
            }
        } else {
            let needAddTag = !hasString && !hasRich
            selectedTypes.insert(.string)
            selectedTypes.insert(.rich)
            if needAddTag {
                let tag = InputTag(
                    icon: AnyView(Image(systemName: "text.document")),
                    label: "文本",
                    type: .filterType,
                    associatedValue: textTagAssociatedValue
                )
                tags.append(tag)
            }
        }
        performSearch()
    }

    func isTextTypeSelected() -> Bool {
        selectedTypes.contains(.string) || selectedTypes.contains(.rich)
    }

    // MARK: - Filter Expression Building

    func buildFilterExpression() -> Expression<Bool>? {
        var conditions: [Expression<Bool>] = []

        // 类型筛选
        if !selectedTypes.isEmpty {
            var tagValues: [String] = []

            for type in selectedTypes {
                let value = type.tagValue
                if !value.isEmpty {
                    tagValues.append(value)
                }
            }

            if !tagValues.isEmpty {
                let tagCondition = tagValues.map { (Col.tag ?? "") == $0 }
                    .reduce(Expression<Bool>(value: false)) { result, condition in
                        result || condition
                    }
                conditions.append(tagCondition)
            }
        }

        // 应用筛选
        if !selectedAppNames.isEmpty {
            let appNamesArray = Array(selectedAppNames)
            let appCondition = appNamesArray.map { Col.appName == $0 }.reduce(
                Expression<Bool>(value: false)
            ) { result, condition in
                result || condition
            }
            conditions.append(appCondition)
        }

        // 日期筛选
        if let dateFilter = selectedDateFilter {
            let (start, end) = dateFilter.timestampRange()
            if let endTimestamp = end {
                let dateCondition = Col.ts >= start && Col.ts < endTimestamp
                conditions.append(dateCondition)
            } else {
                let dateCondition = Col.ts >= start
                conditions.append(dateCondition)
            }
        }

        // 分类筛选
        if !selectedCategoryIds.isEmpty {
            let categoryIdsArray = Array(selectedCategoryIds)
            let categoryCondition = categoryIdsArray.map { Col.group == $0 }
                .reduce(
                    Expression<Bool>(value: false)
                ) { result, condition in
                    result || condition
                }
            conditions.append(categoryCondition)
        }

        return conditions.reduce(nil) { partial, next in
            if let existing = partial {
                return existing && next
            }
            return next
        }
    }

    // MARK: - Search Methods

    private func performSearch() {
        searchTask?.cancel()

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(200))

            guard !Task.isCancelled else { return }
            await executeSearch()
        }
    }

    private func makeSearchCriteria(from trimmedQuery: String)
        -> PasteDataStore.SearchCriteria
    {
        let chipGroup =
            selectedCategoryIds.isEmpty ? getGroupFilterForCurrentChip() : -1
        let filterExpression = buildFilterExpression()

        return PasteDataStore.SearchCriteria(
            keyword: trimmedQuery,
            chipGroup: chipGroup,
            filterExpression: filterExpression
        )
    }

    private func criteriaUnchanged(_ criteria: PasteDataStore.SearchCriteria)
        -> Bool
    {
        criteria.keyword == lastCriteria.keyword
            && criteria.chipGroup == lastCriteria.chipGroup
            && compareExpressions(
                criteria.filterExpression,
                lastCriteria.filterExpression
            )
    }

    private func executeSearch() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let criteria = makeSearchCriteria(from: trimmedQuery)

        if criteriaUnchanged(criteria) {
            return
        }

        let hasFilters = !criteria.isEmpty

        if !hasFilters, selectedChipId == 1 {
            dataStore.resetDefaultList()
        } else {
            dataStore.searchData(criteria)
        }

        lastCriteria = criteria
    }

    private func compareExpressions(
        _ expr1: Expression<Bool>?,
        _ expr2: Expression<Bool>?
    ) -> Bool {
        if expr1 == nil && expr2 == nil {
            return true
        }
        if expr1 == nil || expr2 == nil {
            return false
        }
        return false
    }
}
