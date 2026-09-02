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
            let backfillItems = mapRows(rows)
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
                PasteMetadataCache.shared.invalidateTagTypesCache()
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
                PasteMetadataCache.shared.invalidateTagTypesCache()
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
                PasteMetadataCache.shared.invalidateTagTypesCache()
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
        var dateCom = DateComponents()

        switch timeUnit {
        case let .days(days):
            dateCom = DateComponents(calendar: Calendar.current, day: -days)
        case let .weeks(weeks):
            dateCom = DateComponents(
                calendar: Calendar.current,
                day: -weeks * 7
            )
        case let .months(months):
            dateCom = DateComponents(
                calendar: Calendar.current,
                month: -months
            )
        case .year:
            dateCom = DateComponents(calendar: Calendar.current, year: -1)
        case .forever:
            return
        }

        if let deadDate = Calendar.current.date(byAdding: dateCom, to: Date()) {
            let deadTime = Int64(deadDate.timeIntervalSince1970)
            log.info("清理过期数据，截止时间戳：\(deadTime)")
            let filteredList = dataList.value.filter {
                $0.timestamp > deadTime
            }
            updateData(with: filteredList)
            deleteItems(filter: Col.ts < deadTime && Col.group == -1)
        }
    }

    func clearAllData() {
        let alert = NSAlert()
        alert.informativeText = String(localized: .clearDataMessage)
        alert.addButton(withTitle: String(localized: .commonConfirm))
        alert.addButton(withTitle: String(localized: .commonCancel))
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            Task {
                await sqlManager.dropTable()
                await sqlManager.recreateTable()
                await MainActor.run {
                    PasteMetadataCache.shared.invalidateAllCaches()
                }
                resetToDefault()
            }
        }
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
