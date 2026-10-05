//
//  PasteDataStore+Maintenance.swift
//  Clipboard
//

import AppKit
import Combine
import SQLite

extension PasteDataStore {
    func moveItemsToFirst(_ models: [PasteboardModel]) {
        guard !models.isEmpty else { return }

        let ids = models.compactMap(\.id)
        Task { await sqlManager.promoteItems(ids) }

        let movedIds = Set(models.compactMap(\.id))
        var list = dataList.value.filter { item in
            guard let id = item.id else { return true }
            return !movedIds.contains(id)
        }

        list.insert(contentsOf: models, at: 0)

        if list.count > pageSize {
            list = Array(list.prefix(pageSize))
        }
        updateData(with: list, changeType: .moveToFirst)
    }

    func deleteItems(_ items: PasteboardModel...) {
        deleteItems(items)
    }

    func deleteItems(_ items: [PasteboardModel]) {
        let deletedIds = Set(items.compactMap(\.id))
        var list = dataList.value
        list.removeAll { item in
            guard let id = item.id else { return false }
            return deletedIds.contains(id)
        }
        guard !deletedIds.isEmpty else { return }

        let deficit = pageSize - list.count
        if deficit > 0, hasMoreData {
            deleteAndBackfill(
                deletedIds,
                deficit: deficit,
                currentCount: list.count
            )
        } else {
            updateData(with: list, changeType: .delete)
            deleteStoredItems(deletedIds)
        }
    }

    private func deleteAndBackfill(
        _ deletedIds: Set<Int64>,
        deficit: Int,
        currentCount: Int
    ) {
        let inFilter = isInFilterMode
        let activeFilter = currentFilter

        Task { [weak self, sqlManager] in
            guard let self else { return }

            await sqlManager.delete(filter: deletedIds.contains(Col.id))
            let count = await sqlManager.getTotalCount()
            let filter = inFilter ? activeFilter : nil
            let rows = await sqlManager.search(
                filter: filter ?? (Col.hidden == 0),
                limit: deficit,
                offset: currentCount
            )
            let backfillItems = await mapRows(rows)
            let filtered: Int =
                if inFilter, let activeFilter {
                    await sqlManager.getCount(filter: activeFilter)
                } else {
                    count
                }

            await MainActor.run { [weak self] in
                guard let self else { return }
                totalCount = count
                filteredCount = filtered

                var finalList = dataList.value
                finalList.removeAll { item in
                    guard let id = item.id else { return false }
                    return deletedIds.contains(id)
                }

                let existingIds = Set(finalList.compactMap(\.id))
                let uniqueBackfill = backfillItems.filter { item in
                    guard let id = item.id else { return true }
                    return !existingIds.contains(id)
                }
                finalList += uniqueBackfill

                setHasMoreData(finalList.count >= pageSize)
                updateData(with: finalList, changeType: .delete)
                PasteMetadataCache.shared.invalidateAllCaches()
            }
        }
    }

    private func deleteStoredItems(_ deletedIds: Set<Int64>) {
        let inFilter = isInFilterMode
        let activeFilter = currentFilter

        Task.detached(priority: .utility) { [weak self, sqlManager] in
            await sqlManager.delete(filter: deletedIds.contains(Col.id))
            let count = await sqlManager.getTotalCount()
            let filtered: Int =
                if inFilter, let activeFilter {
                    await sqlManager.getCount(filter: activeFilter)
                } else {
                    count
                }

            await MainActor.run { [weak self] in
                guard let self else { return }
                totalCount = count
                filteredCount = filtered
                PasteMetadataCache.shared.invalidateAllCaches()
            }
        }
    }

    func deleteItems(filter: Expression<Bool>) {
        let inFilter = isInFilterMode
        let activeFilter = currentFilter

        Task.detached(priority: .utility) { [sqlManager] in
            await sqlManager.delete(filter: filter)
            let count = await sqlManager.getTotalCount()

            let filtered: Int =
                if inFilter, let activeFilter {
                    await sqlManager.getCount(filter: activeFilter)
                } else {
                    count
                }

            await MainActor.run { [weak self] in
                guard let self else { return }
                totalCount = count
                filteredCount = filtered
                PasteMetadataCache.shared.invalidateAllCaches()
            }
        }
    }

    func deleteItemsByGroup(_ groupId: Int) {
        deleteItems(filter: Col.group == groupId)
    }

    func remove(at index: Int) {
        var list = dataList.value
        list.remove(at: index)
        dataList.send(list)
    }

    func clearExpiredData() {
        let lastDate = PasteUserDefaults.lastClearDate
        let dateStr = Date().formatted(date: .numeric, time: .omitted)
        if lastDate == dateStr {
            return
        }
        PasteUserDefaults.lastClearDate = dateStr

        let currentValue = PasteUserDefaults.historyTime
        let timeUnit = HistoryTimeUnit(rawValue: currentValue)
        clearData(for: timeUnit)
    }

    func clearData(for timeUnit: HistoryTimeUnit) {
        guard let cutoff = timeUnit.cutoffTimestamp() else { return }
        log.info("清理过期数据，截止时间戳：\(cutoff)")
        let list = dataList.value.filter { $0.group != -1 || $0.timestamp >= cutoff }
        updateData(with: list)
        deleteItems(filter: Col.timestamp < cutoff && Col.group == -1)
    }

    /// 确认并清理超出新期限的记录；设置仅由调用方在成功后保存
    func confirmHistoryLimit(_ timeUnit: HistoryTimeUnit) async -> Bool {
        guard let cutoff = timeUnit.cutoffTimestamp() else { return true }
        do {
            guard try await sqlManager.hasExpiredHistory(before: cutoff) else { return true }
            guard let window = SettingWindowController.shared.window, window.isVisible else { return false }
            let alert = NSAlert.appAlert()
            alert.alertStyle = .warning
            alert.messageText = String(localized: .generalHistoryLimitConfirmTitle)
            alert.informativeText = String(localized: .generalHistoryLimitConfirmMessage)
            alert.addButton(withTitle: String(localized: .commonCancel))
            let deleteButton = alert.addButton(withTitle: String(localized: .delete))
            deleteButton.hasDestructiveAction = true
            guard await alert.beginSheetModal(for: window) == .alertSecondButtonReturn else { return false }

            try await sqlManager.deleteExpiredHistory(before: cutoff)
            PasteMetadataCache.shared.invalidateAllCaches()
            await reloadHistory()
            return true
        } catch {
            log.error("应用历史保留期限失败：\(error)")
            if let window = SettingWindowController.shared.window, window.isVisible {
                let alert = NSAlert.appAlert()
                alert.alertStyle = .warning
                alert.messageText = String(localized: .generalHistoryLimitFailed)
                alert.addButton(withTitle: String(localized: .commonConfirm))
                await alert.beginSheetModal(for: window)
            }
            return false
        }
    }

    func loadHistoryPage() async -> [PasteboardModel]? {
        while !Task.isCancelled {
            let revision = listRevision
            let filterVersion = filterRevision
            let filter = isInFilterMode ? currentFilter : nil
            let rows = await sqlManager.search(filter: filter ?? (Col.hidden == 0), limit: pageSize)
            let list = await mapRows(rows)
            let count = await sqlManager.getTotalCount()
            let filtered = if let filter { await sqlManager.getCount(filter: filter) } else { count }
            guard !Task.isCancelled else { return nil }
            guard revision == listRevision, filterVersion == filterRevision else { continue }
            totalCount = count
            filteredCount = filtered
            setHasMoreData(list.count < filtered)
            return list
        }
        return nil
    }

    func clearAllData() {
        guard !clearingHistory.value else { return }
        let alert = NSAlert.appAlert()
        alert.informativeText = String(localized: .clearDataMessage)
        alert.addButton(withTitle: String(localized: .commonConfirm))
        alert.addButton(withTitle: String(localized: .commonCancel))
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            clearingHistory.send(true)
            Task {
                do {
                    let reclaimed = try await sqlManager.clearHistory()
                    SourceAppCache.shared.replace([])
                    AppColorService.shared.clearColors()
                    PasteMetadataCache.shared.invalidateAllCaches()
                    CategoryChipStore.shared.clearUserCategories()
                    resetToDefault()
                    clearingHistory.send(false)
                    if reclaimed {
                        showClearHistoryResult(String(localized: .clearHistorySuccess), style: .informational)
                    } else {
                        showClearHistoryResult(String(localized: .clearHistorySpaceFailed))
                    }
                } catch {
                    clearingHistory.send(false)
                    log.error("清空历史失败：\(error)")
                    showClearHistoryResult(String(localized: .clearHistoryFailed))
                }
            }
        }
    }

    private func showClearHistoryResult(_ message: String, style: NSAlert.Style = .warning) {
        let alert = NSAlert.appAlert()
        alert.alertStyle = style
        alert.messageText = message
        alert.addButton(withTitle: String(localized: .commonConfirm))
        alert.runModal()
    }

    func updateDbItem(id: Int64, item: PasteboardModel) {
        Task {
            await sqlManager.update(id: id, item: item)
        }
    }

    func updateItemGroupInDB(id: Int64, groupId: Int) async {
        await sqlManager.updateItemGroup(id: id, groupId: groupId)
    }

    func updateItemHidden(itemId: Int64, hidden: Bool) {
        if let model = dataList.value.first(where: { $0.id == itemId }),
           hidden != model.hidden {
            model.updateHidden(val: hidden)
        }

        Task {
            await sqlManager.updateItemHidden(id: itemId, hidden: hidden)
        }
    }

    func getCountByGroup(groupId: Int) async -> Int {
        await sqlManager.getCountByGroup(groupId: groupId)
    }
}
