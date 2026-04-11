//
//  PasteDataStore.swift
//  Clipboard
//
//  Created by crown on 2025/9/15.
//

import AppKit
import Combine
import SQLite
import SwiftUI

typealias Expression = SQLite.Expression

final class PasteDataStore {
    static let main = PasteDataStore()
    let pageSize = 50

    private(set) var dataList = CurrentValueSubject<[PasteboardModel], Never>([])

    private(set) var searchWord: String = ""
    private(set) var chipsVersion: Int = 0

    var totalCount: Int = 0
    private(set) var pageIndex = 0
    private(set) var isLoadingPage = false
    private(set) var hasMoreData = false
    var filteredCount: Int = 0

    enum DataChangeType {
        case loadMore
        case searchFilter
        case reset
    }

    private(set) var lastDataChangeType: DataChangeType = .reset

    private var currentFilter: Expression<Bool>?
    private(set) var isInFilterMode: Bool = false
    private var lastRequestedPage = 0

    private let sqlManager = PasteSQLManager.manager
    private var searchTask: Task<Void, Error>?
    private var loadPageTask: Task<Void, Never>?

    func setup() {
        Task {
            await resetDefaultList()
            let count = await sqlManager.getTotalCount()
            totalCount = count
            filteredCount = count
        }
        setupChipObserver()
    }

    private func setupChipObserver() {
        NotificationCenter.default.addObserver(
            forName: .categoryChipsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.chipsVersion &+= 1
            }
        }
    }

    func notifyCategoryChipsChanged() {
        chipsVersion &+= 1
    }

    func updateData(
        with list: [PasteboardModel],
        changeType: DataChangeType = .reset
    ) {
        dataList.send(list)
        lastDataChangeType = changeType
    }
}

// MARK: - Row → Model 映射

extension PasteDataStore {
    private func getItems(limit: Int = 50, offset: Int? = nil) async
        -> [PasteboardModel]
    {
        let rows = await sqlManager.search(
            filter: Col.hidden == 0,
            limit: limit,
            offset: offset
        )
        return mapRows(rows)
    }

    private func mapRows(_ rows: [Row]) -> [PasteboardModel] {
        rows.compactMap { row in
            if let type = try? row.get(Col.type),
               let data = try? row.get(Col.data),
               let timestamp = try? row.get(Col.ts)
            {
                let id = try? row.get(Col.id)
                let appName = try? row.get(Col.appName)
                let appPath = try? row.get(Col.appPath)
                var showData = try? row.get(Col.showData)
                let searchText = try? row.get(Col.searchText)
                let length = try? row.get(Col.length)
                let group = try? row.get(Col.group)
                let tag = try? row.get(Col.tag)
                let hidden = ((try? row.get(Col.hidden)) ?? 0) != 0

                let pType = PasteboardType(type)

                if pType.isText(), showData == nil {
                    if let searchText {
                        showData = String(searchText.prefix(300)).data(
                            using: .utf8
                        )
                    }
                }

                let pasteModel = PasteboardModel(
                    pasteboardType: pType,
                    data: data,
                    showData: showData,
                    timestamp: timestamp,
                    appPath: appPath ?? "",
                    appName: appName ?? "",
                    searchText: searchText ?? "",
                    length: length ?? 0,
                    group: group ?? -1,
                    tag: tag ?? "",
                    hidden: hidden
                )
                pasteModel.id = id
                return pasteModel
            }
            return nil
        }
    }
}

// MARK: - 数据操作

extension PasteDataStore {
    func loadNextPage() {
        guard !isLoadingPage else { return }
        guard dataList.value.count < totalCount else { return }

        let nextPage = pageIndex + 1
        guard nextPage != lastRequestedPage else { return }

        loadPageTask?.cancel()

        isLoadingPage = true
        lastRequestedPage = nextPage
        pageIndex = nextPage

        let currentOffset = dataList.value.count
        let filter = isInFilterMode ? currentFilter : nil

        log.debug(
            "loadNextPage \(pageIndex) (filterMode: \(isInFilterMode))"
        )

        loadPageTask = Task { [weak self] in
            guard let self else { return }

            let newItems: [PasteboardModel]
            if let filter {
                let rows = await sqlManager.search(
                    filter: filter,
                    limit: pageSize,
                    offset: currentOffset
                )
                newItems = mapRows(rows)
            } else {
                newItems = await getItems(
                    limit: pageSize,
                    offset: currentOffset
                )
            }

            guard !Task.isCancelled else { return }

            guard !newItems.isEmpty else {
                hasMoreData = false
                isLoadingPage = false
                return
            }

            var list = dataList.value
            list += newItems

            updateData(with: list, changeType: .loadMore)
            hasMoreData = (newItems.count == pageSize)
            isLoadingPage = false
        }
    }

    func resetDefaultList() async {
        pageIndex = 0
        currentFilter = nil
        isInFilterMode = false
        searchWord = ""
        let list = await getItems(limit: pageSize, offset: pageSize * pageIndex)
        filteredCount = totalCount
        updateData(with: list)
        hasMoreData = list.count == pageSize
    }

    func resetToDefault() {
        searchTask?.cancel()
        loadPageTask?.cancel()
        isLoadingPage = false
        lastRequestedPage = 0
        Task {
            await resetDefaultList()
        }
    }

    /// 数据搜索（关键词 + 自定义分组 + 过滤视图）
    func searchData(_ criteria: SearchCriteria) {
        searchTask?.cancel()

        searchTask = Task {
            let filter = PasteFilterBuilder.buildFilter(from: criteria)

            searchWord = criteria.keyword
            currentFilter = filter
            isInFilterMode = (filter != nil)
            pageIndex = 0
            lastRequestedPage = 0

            let rows = await sqlManager.search(filter: filter, limit: pageSize)
            try Task.checkCancellation()

            let count = await sqlManager.getCount(filter: filter)
            try Task.checkCancellation()

            let result = mapRows(rows)

            filteredCount = count
            updateData(with: result, changeType: .searchFilter)
            hasMoreData = result.count == pageSize
        }
    }

    func addNewItem(_ item: NSPasteboard) {
        guard let model = PasteboardModel(with: item) else { return }

        insertModel(model)
        AppColorService.shared.updateColor(for: model)

        Task {
            await runOCRIfNeeded(model)
        }

        PasteMetadataCache.shared.invalidateAppInfoCache(model)
        PasteMetadataCache.shared.invalidateTagTypesCache(model)
    }

    func runOCRIfNeeded(_ model: PasteboardModel) async {
        guard model.type == .image, let id = model.id else { return }

        let searchText = await OCRViewModel.shared.recognizeText(
            from: model.data
        )

        guard !searchText.isEmpty else { return }

        model.updateSearchText(val: searchText)
        await sqlManager.update(id: id, item: model)
    }

    func insertModel(_ model: PasteboardModel) {
        Task {
            let itemId = await sqlManager.insert(item: model)
            let count = await sqlManager.getTotalCount()

            model.id = itemId
            totalCount = count

            if isInFilterMode, let filter = currentFilter {
                filteredCount = await sqlManager.getCount(filter: filter)
            } else {
                filteredCount = count
            }

            if lastDataChangeType == .searchFilter {
                return
            }

            var list = dataList.value
            list.removeAll(where: { $0.uniqueId == model.uniqueId })
            list.insert(model, at: 0)
            hasMoreData = list.count >= pageSize
            updateData(with: Array(list.prefix(pageSize)))
        }
    }

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
        if lastDataChangeType == .loadMore {
            lastDataChangeType = .reset
        }
        updateData(with: list, changeType: lastDataChangeType)
    }

    func deleteItems(_ items: PasteboardModel...) {
        let ids = items.compactMap(\.id)
        guard !ids.isEmpty else { return }
        deleteItems(filter: ids.contains(Col.id))
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

    func delete(id: Int64) {
        Task {
            await sqlManager.delete(id: id)
        }
    }

    func remove(at index: Int) {
        var list = dataList.value
        list.remove(at: index)
        dataList.send(list)
    }

    func clearExpiredData() {
        let lastDate = PasteUserDefaults.lastClearDate
        let dateStr = Date().formatted(date: .numeric, time: .omitted)
        if lastDate == dateStr { return }
        PasteUserDefaults.lastClearDate = dateStr

        let currentValue = PasteUserDefaults.historyTime
        let timeUnit = HistoryTimeUnit(rawValue: currentValue)
        clearData(for: timeUnit)
    }

    func clearData(for timeUnit: HistoryTimeUnit) {
        var dateCom = DateComponents()

        switch timeUnit {
        case let .days(n):
            dateCom = DateComponents(calendar: Calendar.current, day: -n)
        case let .weeks(n):
            dateCom = DateComponents(calendar: Calendar.current, day: -n * 7)
        case let .months(n):
            dateCom = DateComponents(calendar: Calendar.current, month: -n)
        case .year:
            dateCom = DateComponents(calendar: Calendar.current, year: -1)
        case .forever:
            return
        }

        if let deadDate = Calendar.current.date(byAdding: dateCom, to: Date()) {
            let deadTime = Int64(deadDate.timeIntervalSince1970)
            log.info("清理过期数据，截止时间戳：\(deadTime)")
            dataList.value = dataList.value.filter { $0.timestamp > deadTime }
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
                resetToDefault()
            }
        }
    }

    func updateDbItem(id: Int64, item: PasteboardModel) {
        Task {
            await sqlManager.update(id: id, item: item)
        }
    }

    /// 编辑更新
    func updateItemContent(
        id: Int64,
        newData: Data,
        newShowData: Data?,
        newSearchText: String,
        newLength: Int,
        newTag: String
    ) async {
        await sqlManager.updateItemContent(
            id: id,
            data: newData,
            showData: newShowData,
            searchText: newSearchText,
            length: newLength,
            tag: newTag
        )

        var list = dataList.value
        if let index = list.firstIndex(where: { $0.id == id }) {
            let oldModel = list[index]
            let newModel = PasteboardModel(
                pasteboardType: oldModel.pasteboardType,
                data: newData,
                showData: newShowData,
                timestamp: Int64(Date().timeIntervalSince1970),
                appPath: oldModel.appPath,
                appName: oldModel.appName,
                searchText: newSearchText,
                length: newLength,
                group: oldModel.group,
                tag: newTag
            )
            newModel.id = id
            list.remove(at: index)
            list.insert(newModel, at: 0)
            dataList.value = list
        }
    }

    func updateItemGroup(itemId: Int64, groupId: Int) {
        if let model = dataList.value.first(where: { $0.id == itemId }),
           groupId != model.group
        {
            model.updateGroup(val: groupId)
        }

        Task {
            await sqlManager.updateItemGroup(
                id: itemId,
                groupId: groupId
            )
        }
    }

    func updateItemHidden(itemId: Int64, hidden: Bool) {
        if let model = dataList.value.first(where: { $0.id == itemId }),
           hidden != model.hidden
        {
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
