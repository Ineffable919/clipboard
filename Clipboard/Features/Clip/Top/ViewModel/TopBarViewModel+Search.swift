import AppKit
import Combine

extension TopBarViewModel {
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

    func parseShortcutCommand(_ command: String) -> PasteModelType? {
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
        selectedAppIDs.removeAll()
        selectedDateFilter = nil
        selectedGroupIds.removeAll()

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
            selectedAppIDs: selectedAppIDs,
            selectedDateFilter: selectedDateFilter,
            selectedGroupIds: selectedGroupIds
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
            selectedAppIDs: selectedAppIDs,
            selectedDateFilter: selectedDateFilter,
            selectedGroupIds: selectedGroupIds
        )

        if criteria == lastSearchCriteria {
            return
        }
        lastSearchCriteria = criteria

        if criteria.isEmpty {
            store.resetToDefault()
        } else {
            store.searchData(criteria)
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

    func pauseTimeString(from date: Date) -> String {
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
            await store.updateItemGroupInDB(id: modelId, groupId: chipId)
        }

        if !selectedGroupIds.isEmpty, !selectedGroupIds.contains(chipId) {
            var list = store.dataList.value
            list.removeAll(where: { $0.id == modelId })
            store.updateData(with: list, changeType: .delete)
        } else {
            if let model = store.dataList.value.first(where: { $0.id == modelId }),
               chipId != model.group {
                model.updateGroup(val: chipId)
            }
            store.updateData(with: store.dataList.value, changeType: .update)
        }

        return true
    }
}
