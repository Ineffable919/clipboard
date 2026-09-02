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
        case new
        case delete
        case moveToFirst
        case update
    }

    private(set) var lastDataChangeType: DataChangeType = .reset

    private(set) var currentFilter: Expression<Bool>?
    private(set) var isInFilterMode: Bool = false
    private var lastRequestedPage = 0

    let sqlManager = PasteSQLManager.manager
    private var searchTask: Task<Void, Error>?
    private var loadPageTask: Task<Void, Never>?
    private var repairingTagIds = Set<Int64>()

    func setup() async {
        await sqlManager.setup()
        await resetDefaultList()
        let count = await sqlManager.getTotalCount()
        totalCount = count
        filteredCount = count
    }

    func notifyCategoryChipsChanged() {
        chipsVersion &+= 1
    }

    func updateData(
        with list: [PasteboardModel],
        changeType: DataChangeType = .reset
    ) {
        lastDataChangeType = changeType
        dataList.send(list)
    }

    func setHasMoreData(_ value: Bool) {
        hasMoreData = value
    }
}

// MARK: - Row → Model 映射

extension PasteDataStore {
    private func getItems(limit: Int = 50, offset: Int? = nil) async
        -> [PasteboardModel] {
        let rows = await sqlManager.search(
            filter: Col.hidden == 0,
            limit: limit,
            offset: offset
        )
        return mapRows(rows)
    }

    func mapRows(_ rows: [Row]) -> [PasteboardModel] {
        rows.compactMap { row in
            if let type = try? row.get(Col.type),
               let data = try? row.get(Col.data),
               let timestamp = try? row.get(Col.ts),
               let uniqueId = try? row.get(Col.uniqueId) {
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
                    if let plain = NSAttributedString(
                        with: data,
                        type: pType
                    )?.string ?? String(data: data, encoding: .utf8) {
                        showData = String(plain.prefix(300)).data(
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
                    hidden: hidden,
                    uniqueId: uniqueId
                )
                pasteModel.id = id
                repairTagIfNeeded(pasteModel)
                return pasteModel
            }
            return nil
        }
    }

    private func repairTagIfNeeded(_ model: PasteboardModel) {
        guard let storedType = PasteModelType(rawValue: model.tag),
              storedType == .link || storedType == .color,
              model.type != storedType,
              let id = model.id
        else {
            return
        }

        let correctedTag = model.type.tagValue
        guard !correctedTag.isEmpty,
              repairingTagIds.insert(id).inserted
        else {
            return
        }

        Task { [weak self] in
            guard let self else { return }

            let updated = await sqlManager.updateItemTag(
                id: id,
                expectedTag: storedType.tagValue,
                newTag: correctedTag
            )
            repairingTagIds.remove(id)

            if updated {
                PasteMetadataCache.shared.invalidateTagTypesCache()
            }
        }
    }
}

// MARK: - 数据操作

extension PasteDataStore {
    func loadNextPage() {
        guard !isLoadingPage else { return }
        let effectiveTotal = isInFilterMode ? filteredCount : totalCount
        guard dataList.value.count < effectiveTotal else { return }

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

    @discardableResult
    func addNewItem(_ item: NSPasteboard, sourceApp: NSRunningApplication? = nil, chipId: Int = -1) -> Bool {
        guard let model = PasteboardModel(with: item, sourceApp: sourceApp) else { return false }

        if chipId != -1 {
            model.updateGroup(val: chipId)
        }

        AppColorService.shared.updateColor(for: model)
        PasteMetadataCache.shared.invalidateAppInfoCache(model)
        PasteMetadataCache.shared.invalidateTagTypesCache(model)

        Task {
            await insertModel(model)
            await runOCRIfNeeded(model)
        }
        return true
    }

    func runOCRIfNeeded(_ model: PasteboardModel) async {
        guard model.type == .image, let id = model.id else { return }

        let rawText = await OCRViewService.shared.recognizeText(
            from: model.data
        )

        guard !rawText.isEmpty else { return }

        let searchText = PasteboardModel.normalizeSearchText(rawText)
        model.updateSearchText(val: searchText)
        await sqlManager.update(id: id, item: model)
    }

    func insertModel(_ model: PasteboardModel) async {
        let (itemId, existingGroup) = await sqlManager.insert(
            item: model,
            timestamp: model.timestamp,
            group: model.group
        )
        let count = await sqlManager.getTotalCount()

        model.id = itemId
        if let group = existingGroup {
            model.updateGroup(val: group)
        }
        totalCount = count

        if isInFilterMode, let filter = currentFilter {
            filteredCount = await sqlManager.getCount(filter: filter)
            guard let id = model.id,
                  await sqlManager.getCount(filter: filter && Col.id == id) > 0
            else { return }
        } else {
            filteredCount = count
        }

        var list = dataList.value
        list.removeAll(where: { $0.uniqueId == model.uniqueId })
        list.insert(model, at: 0)
        let truncated = Array(list.prefix(pageSize))
        hasMoreData = list.count >= pageSize

        pageIndex = 0
        lastRequestedPage = 0
        loadPageTask?.cancel()
        isLoadingPage = false

        updateData(with: truncated, changeType: .new)
    }

    /// 编辑更新
    func updateItemContent(
        id: Int64,
        content: PasteContent
    ) async -> Bool {
        let searchText = PasteboardModel.normalizeSearchText(
            content.searchText
        )
        let loadedLimit = max(pageSize, dataList.value.count)
        loadPageTask?.cancel()
        isLoadingPage = false

        guard await sqlManager.updateItemContent(
            id: id,
            type: content.type,
            data: content.data,
            showData: content.showData,
            searchText: searchText,
            length: content.length,
            tag: content.tag
        ) else {
            return false
        }

        let list: [PasteboardModel]
        if isInFilterMode, let currentFilter {
            let rows = await sqlManager.search(
                filter: currentFilter,
                limit: loadedLimit
            )
            list = mapRows(rows)
        } else {
            list = await getItems(limit: loadedLimit)
        }

        totalCount = await sqlManager.getTotalCount()
        if isInFilterMode, let currentFilter {
            filteredCount = await sqlManager.getCount(filter: currentFilter)
        } else {
            filteredCount = totalCount
        }
        let effectiveTotal = isInFilterMode ? filteredCount : totalCount
        hasMoreData = list.count < effectiveTotal
        pageIndex = max(0, (list.count - 1) / pageSize)
        lastRequestedPage = pageIndex
        updateData(with: list, changeType: .moveToFirst)
        return true
    }

}
