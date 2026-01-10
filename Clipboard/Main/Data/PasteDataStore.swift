//
//  PasteDataStore.swift
//  Clipboard
//
//  Created by crown on 2025/9/15.
//

import AppKit
import SQLite
import SwiftUI

typealias Expression = SQLite.Expression

@Observable
final class PasteDataStore {
    static let main = PasteDataStore()
    private let pageSize = 50
    var dataList: [PasteboardModel] = []

    private(set) var currentSearchKeyword: String = ""

    private(set) var chipsVersion: Int = 0

    var totalCount: Int = 0
    private(set) var pageIndex = 0

    private(set) var isLoadingPage = false
    private var lastRequestedPage = 0

    private(set) var hasMoreData = false

    enum DataChangeType {
        case loadMore
        case searchFilter
        case reset
    }

    private(set) var lastDataChangeType: DataChangeType = .reset

    private var currentFilter: Expression<Bool>?
    private(set) var isInFilterMode: Bool = false

    private var sqlManager = PasteSQLManager.manager
    private var searchTask: Task<Void, Error>?
    private var loadPageTask: Task<Void, Never>?
    private var colorDict = [String: String]()
    private var cachedAppInfo: [(name: String, path: String)]?
    private var cachedTagTypes: [PasteModelType]?

    func setup() {
        Task {
            await resetDefaultList()
            let count = await sqlManager.getTotalCount()
            await MainActor.run {
                totalCount = count
            }
        }
        colorDict = PasteUserDefaults.appColorData
    }

    @MainActor
    func notifyCategoryChipsChanged() {
        chipsVersion &+= 1
    }

    @MainActor
    func updateData(
        with list: [PasteboardModel],
        changeType: DataChangeType = .reset,
    ) {
        dataList = list
        lastDataChangeType = changeType
    }
}

// MARK: - private 辅助方法

extension PasteDataStore {
    private func updateTotalCount() async {
        totalCount = await sqlManager.getTotalCount()
    }

    private func getItems(limit: Int = 50, offset: Int? = nil) async
        -> [PasteboardModel]
    {
        let rows = await sqlManager.search(limit: limit, offset: offset)
        return await getItems(rows: rows)
    }

    private func getItems(rows: [Row]) async -> [PasteboardModel] {
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

                let pType = PasteboardType(type)

                if pType.isText(), showData == nil {
                    if let searchText {
                        showData = String(searchText.prefix(300)).data(
                            using: .utf8,
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
                )
                pasteModel.id = id
                return pasteModel
            }
            return nil
        }
    }

    private func calculateTagValue(type: PasteboardType, data: Data) -> String {
        switch type {
        case .rtf, .rtfd:
            return "rich"
        case .string:
            if let str = String(data: data, encoding: .utf8) {
                if str.isCSSHexColor {
                    return "color"
                } else if str.asCompleteURL() != nil {
                    return "link"
                }
            }
            return "string"
        case .png, .tiff:
            return "image"
        case .fileURL:
            return "file"
        default:
            return ""
        }
    }

    private func buildFilter(from criteria: TopBarViewModel.SearchCriteria)
        -> Expression<Bool>?
    {
        var clauses: [Expression<Bool>] = []

        // 关键词搜索
        if !criteria.keyword.isEmpty {
            clauses.append(Col.searchText.like("%\(criteria.keyword)%"))
        }

        // 分组筛选
        if criteria.chipGroup != -1 {
            clauses.append(Col.group == criteria.chipGroup)
        }

        // 类型筛选
        if !criteria.selectedTypes.isEmpty {
            var tagValues: [String] = []
            for type in criteria.selectedTypes {
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
                clauses.append(tagCondition)
            }
        }

        // 应用筛选
        if !criteria.selectedAppNames.isEmpty {
            let appCondition = criteria.selectedAppNames.map { Col.appName == $0 }
                .reduce(Expression<Bool>(value: false)) { $0 || $1 }
            clauses.append(appCondition)
        }

        // 日期筛选
        if let dateFilter = criteria.selectedDateFilter {
            let (start, end) = dateFilter.timestampRange()
            if let endTimestamp = end {
                let dateCondition = Col.ts >= start && Col.ts < endTimestamp
                clauses.append(dateCondition)
            } else {
                let dateCondition = Col.ts >= start
                clauses.append(dateCondition)
            }
        }

        return clauses.reduce(nil) { partial, next in
            if let existing = partial {
                return existing && next
            }
            return next
        }
    }
}

// MARK: - 数据操作

extension PasteDataStore {
    func loadNextPage() {
        guard !isLoadingPage else { return }
        guard dataList.count < totalCount else { return }

        let nextPage = pageIndex + 1
        guard nextPage != lastRequestedPage else { return }

        loadPageTask?.cancel()

        isLoadingPage = true
        lastRequestedPage = nextPage
        pageIndex = nextPage

        let currentOffset = dataList.count
        let filter = isInFilterMode ? currentFilter : nil

        log.debug(
            "loadNextPage \(pageIndex) (filterMode: \(isInFilterMode))",
        )

        loadPageTask = Task { [weak self] in
            guard let self else { return }

            let newItems: [PasteboardModel]
            if let filter {
                let rows = await sqlManager.search(
                    filter: filter,
                    limit: pageSize,
                    offset: currentOffset,
                )
                newItems = await getItems(rows: rows)
            } else {
                newItems = await getItems(
                    limit: pageSize,
                    offset: currentOffset,
                )
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !newItems.isEmpty else {
                    hasMoreData = false
                    isLoadingPage = false
                    return
                }

                var list = dataList
                list += newItems

                updateData(with: list, changeType: .loadMore)
                hasMoreData = (newItems.count == pageSize)
                isLoadingPage = false
            }
        }
    }

    func resetDefaultList() async {
        pageIndex = 0
        currentFilter = nil
        isInFilterMode = false
        currentSearchKeyword = ""
        let list = await getItems(limit: pageSize, offset: pageSize * pageIndex)
        updateData(with: list)
        hasMoreData = list.count == pageSize
    }

    /// 数据搜索（关键词 + 自定义分组 + 过滤视图）
    func searchData(_ criteria: TopBarViewModel.SearchCriteria) async {
        searchTask?.cancel()
        searchTask = Task {
            let filter = buildFilter(from: criteria)

            currentSearchKeyword = criteria.keyword

            currentFilter = filter
            isInFilterMode = (filter != nil)
            pageIndex = 0
            lastRequestedPage = 0

            let rows = await sqlManager.search(filter: filter, limit: pageSize)
            try Task.checkCancellation()

            let result = await getItems(rows: rows)
            try Task.checkCancellation()

            updateData(with: result, changeType: .searchFilter)
            hasMoreData = result.count == pageSize
        }
    }

    func addNewItem(_ item: NSPasteboard) {
        guard let model = PasteboardModel(with: item) else { return }
        insertModel(model)
        Task {
            await updateColor(model)
        }
        Task {
            if model.type == .image, let id = model.id {
                let searchText = await OCRViewModel.shared.recognizeText(
                    from: model.data
                )
                model.updateSearchText(val: searchText)
                await sqlManager.update(id: id, item: model)
            }
        }
        invalidateAppInfoCache(model)
        invalidateTagTypesCache(model)
    }

    func insertModel(_ model: PasteboardModel) {
        Task {
            let itemId: Int64
            await itemId = sqlManager.insert(item: model)
            model.id = itemId
            await updateTotalCount()
            if lastDataChangeType == .searchFilter {
                return
            }
            var list = dataList
            list.removeAll(where: { $0.uniqueId == model.uniqueId })
            list.insert(model, at: 0)
            hasMoreData = list.count >= pageSize
            list = Array(list.prefix(pageSize))
            updateData(with: list)
        }
    }

    @MainActor
    func moveItemToFirst(_ model: PasteboardModel) {
        var list = dataList

        if let index = list.firstIndex(where: { $0.id == model.id }) {
            guard index != 0 else { return }
            list.remove(at: index)
        }

        list.insert(model, at: 0)

        if list.count > pageSize {
            list = Array(list.prefix(pageSize))
        }
        if lastDataChangeType == .loadMore {
            lastDataChangeType = .reset
        }
        updateData(with: list, changeType: lastDataChangeType)
    }

    func deleteItems(_ items: PasteboardModel...) {
        deleteItems(filter: items.map { $0.id! }.contains(Col.id))
    }

    func deleteItems(filter: Expression<Bool>) {
        Task {
            await sqlManager.delete(filter: filter)
            await updateTotalCount()
            invalidateTagTypesCache()
        }
    }

    func deleteItemsByGroup(_ groupId: Int) {
        deleteItems(filter: Col.group == groupId)
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
            // 1-6天
            dateCom = DateComponents(calendar: NSCalendar.current, day: -n)
        case let .weeks(n):
            // 1-3周
            dateCom = DateComponents(calendar: NSCalendar.current, day: -n * 7)
        case let .months(n):
            // 1-11月
            dateCom = DateComponents(calendar: NSCalendar.current, month: -n)
        case .year:
            // 1年
            dateCom = DateComponents(calendar: NSCalendar.current, year: -1)
        case .forever:
            // 永久保留，不删除
            return
        }

        if let deadDate = NSCalendar.current.date(byAdding: dateCom, to: Date()) {
            let deadTime = Int64(deadDate.timeIntervalSince1970)
            log.info("清理过期数据，截止时间戳：\(deadTime)")
            dataList = dataList.filter { $0.timestamp > deadTime }
            deleteItems(filter: Col.ts < deadTime && Col.group == -1)
        }
    }

    func clearAllData() {
        let alert = NSAlert()
        alert.informativeText = """
                清空数据后无法恢复
                清空后会退出应用，请重新打开。
        """
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            Task {
                await sqlManager.dropTable()
            }
            NSApplication.shared.terminate(self)
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

        await MainActor.run {
            if let index = dataList.firstIndex(where: { $0.id == id }) {
                let oldModel = dataList[index]
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
                dataList.remove(at: index)
                dataList.insert(newModel, at: 0)
            }
        }
    }

    func updateItemGroup(itemId: Int64, groupId: Int) throws {
        Task {
            await sqlManager.updateItemGroup(
                id: itemId,
                groupId: groupId
            )
        }
        Task { @MainActor in
            if let model = dataList.first(where: { $0.id == itemId }),
               groupId != model.group
            {
                model.updateGroup(val: groupId)
            }
        }
    }

    func getAllAppInfo() async -> [(name: String, path: String)] {
        if let cached = cachedAppInfo {
            return cached
        }

        let appInfo = await sqlManager.getDistinctAppInfo()
        cachedAppInfo = appInfo
        return appInfo
    }

    func invalidateAppInfoCache(_ model: PasteboardModel) {
        if let index = cachedAppInfo?.firstIndex(where: {
            $0.name == model.appName
        }) {
            cachedAppInfo?[index].path = model.appPath
        } else {
            cachedAppInfo?.append((name: model.appName, path: model.appPath))
        }
    }

    func getAllTagTypes() async -> [PasteModelType] {
        if let cached = cachedTagTypes {
            return cached
        }

        let tags = await sqlManager.getDistinctTags()
        let types = tags.compactMap { tag -> PasteModelType? in
            switch tag {
            case "image": return .image
            case "string": return .string
            case "rich": return .rich
            case "file": return .file
            case "link": return .link
            case "color": return .color
            default: return nil
            }
        }

        var finalTypes: [PasteModelType] = []
        let hasString = types.contains(.string)
        let hasRich = types.contains(.rich)

        if hasString || hasRich {
            finalTypes.append(.string)
        }

        for type in types where type != .string && type != .rich {
            if !finalTypes.contains(type) {
                finalTypes.append(type)
            }
        }

        let order: [PasteModelType] = [.color, .file, .image, .link, .string]
        finalTypes.sort { type1, type2 in
            let index1 = order.firstIndex(of: type1) ?? order.count
            let index2 = order.firstIndex(of: type2) ?? order.count
            return index1 < index2
        }

        cachedTagTypes = finalTypes
        return finalTypes
    }

    func invalidateTagTypesCache(_ model: PasteboardModel? = nil) {
        guard let model, !model.tag.isEmpty else {
            cachedTagTypes = nil
            return
        }

        let modelType: PasteModelType? =
            switch model.tag {
            case "image": .image
            case "string", "rich": .string
            case "file": .file
            case "link": .link
            case "color": .color
            default: nil
            }

        guard let modelType else { return }

        Task {
            if cachedTagTypes == nil {
                cachedTagTypes = await getAllTagTypes()
            }

            guard let cachedTagTypes, !cachedTagTypes.contains(modelType) else {
                return
            }

            var updatedTypes = cachedTagTypes
            updatedTypes.append(modelType)

            let order: [PasteModelType] = [
                .color, .file, .image, .link, .string,
            ]
            updatedTypes.sort { type1, type2 in
                let index1 = order.firstIndex(of: type1) ?? order.count
                let index2 = order.firstIndex(of: type2) ?? order.count
                return index1 < index2
            }

            self.cachedTagTypes = updatedTypes
        }
    }

    func getCountByGroup(groupId: Int) async -> Int {
        await sqlManager.getCountByGroup(groupId: groupId)
    }
}

// MARK: - 颜色处理

extension PasteDataStore {
    func updateColor(_ model: PasteboardModel) async {
        if colorDict[model.appName] == nil {
            let iconImage = NSWorkspace.shared.icon(forFile: model.appPath)
            let hex = getAppThemeColor(for: model.appName, appIcon: iconImage)
            colorDict[model.appName] = hex
            PasteUserDefaults.appColorData = colorDict
        }
    }

    func colorWith(_ model: PasteboardModel) -> Color {
        let _ = chipsVersion

        if let chip = model.getGroupChip() {
            return chip.color
        }

        if let colorStr = colorDict[model.appName] {
            return Color(nsColor: NSColor(hex: colorStr)).opacity(0.85)
        }
        return Color(nsColor: NSColor(hex: "#1765D9")).opacity(0.85)
    }

    private func getAppThemeColor(for _: String, appIcon: NSImage?) -> String {
        guard let icon = appIcon else {
            return "#1765D9"
        }

        if let extractedColor = extractDominantColorOptimized(from: icon) {
            return extractedColor
        }
        return "#1765D9"
    }

    private func extractDominantColorOptimized(from image: NSImage) -> String? {
        let targetSize = CGSize(width: 32, height: 32)

        guard let resizedImage = resizeImage(image, to: targetSize),
              let cgImage = resizedImage.cgImage(
                  forProposedRect: nil,
                  context: nil,
                  hints: nil,
              )
        else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue,
        )

        guard
            let context = CGContext(
                data: nil,
                width: Int(targetSize.width),
                height: Int(targetSize.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue,
            )
        else { return nil }

        context.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))

        guard let data = context.data else { return nil }
        let pixelData = data.bindMemory(
            to: UInt8.self,
            capacity: Int(targetSize.width * targetSize.height * 4),
        )

        var colorCounts: [UInt32: Float] = [:]
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)

        for y in 0 ..< height {
            for x in 0 ..< width {
                let pixelIndex = (y * width + x) * 4
                let alpha = Int(pixelData[pixelIndex + 3])

                if alpha > 128 {
                    let r = Int(pixelData[pixelIndex])
                    let g = Int(pixelData[pixelIndex + 1])
                    let b = Int(pixelData[pixelIndex + 2])

                    if isValidColor(r: r, g: g, b: b) {
                        let quantizedR = (r / 8) * 8
                        let quantizedG = (g / 8) * 8
                        let quantizedB = (b / 8) * 8

                        let colorKey =
                            (UInt32(quantizedR) << 16)
                                | (UInt32(quantizedG) << 8) | UInt32(quantizedB)

                        // 计算位置权重
                        let weight = calculateSimpleWeight(
                            x: x,
                            y: y,
                            width: width,
                            height: height,
                        )
                        colorCounts[colorKey, default: 0] += weight
                    }
                }
            }
        }

        var colorGroupWeights: [ColorGroup: Float] = [:]
        var colorGroupCache: [UInt32: ColorGroup] = [:]

        for (color, count) in colorCounts {
            let r = Int((color >> 16) & 0xFF)
            let g = Int((color >> 8) & 0xFF)
            let b = Int(color & 0xFF)

            let group = getColorGroup(r: r, g: g, b: b)
            colorGroupCache[color] = group
            if group != .other {
                colorGroupWeights[group, default: 0] += count
            }
        }

        let totalWeight = colorGroupWeights.values.reduce(0, +)
        let greenBlueWeight =
            (colorGroupWeights[.green] ?? 0) + (colorGroupWeights[.blue] ?? 0)

        // 如果绿色和蓝色的总权重超过20%，就认为是多彩图标，需要抑制红黄色
        let shouldSuppressWarmColors =
            totalWeight > 0 && (greenBlueWeight / totalWeight > 0.2)

        var bestColor: UInt32?
        var bestScore: Float = 0

        for (color, count) in colorCounts {
            let r = Int((color >> 16) & 0xFF)
            let g = Int((color >> 8) & 0xFF)
            let b = Int(color & 0xFF)

            let quality = getSimpleColorQuality(r: r, g: g, b: b)
            var score = count * quality

            if shouldSuppressWarmColors {
                let group = colorGroupCache[color] ?? .other
                switch group {
                case .red:
                    score *= 0.1 // 红色优先级最低
                case .yellow:
                    score *= 1.2 // 黄色第二低
                default:
                    break
                }
            }

            if score > bestScore {
                bestScore = score
                bestColor = color
            }
        }

        guard let dominantColor = bestColor else { return nil }

        let r = Int((dominantColor >> 16) & 0xFF)
        let g = Int((dominantColor >> 8) & 0xFF)
        let b = Int(dominantColor & 0xFF)

        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private enum ColorGroup {
        case red, green, blue, yellow, other
    }

    private func getColorGroup(r: Int, g: Int, b: Int) -> ColorGroup {
        let hue = rgbToHue(r: r, g: g, b: b)
        let saturation = rgbToSaturation(r: r, g: g, b: b)

        if saturation < 0.2 { return .other }

        if hue >= 330 || hue < 30 {
            return .red
        } else if hue >= 30, hue < 90 {
            return .yellow
        } else if hue >= 90, hue < 180 {
            return .green
        } else if hue >= 180, hue < 270 {
            return .blue
        }
        return .other
    }

    private func rgbToHue(r: Int, g: Int, b: Int) -> Float {
        let R = Float(r) / 255.0
        let G = Float(g) / 255.0
        let B = Float(b) / 255.0

        let maxC = max(R, G, B)
        let minC = min(R, G, B)
        let delta = maxC - minC

        var hue: Float = 0.0
        if delta > 0 {
            if maxC == R {
                hue = 60 * fmod((G - B) / delta, 6)
            } else if maxC == G {
                hue = 60 * (((B - R) / delta) + 2)
            } else {
                hue = 60 * (((R - G) / delta) + 4)
            }
        }

        if hue < 0 {
            hue += 360
        }
        return hue
    }

    private func rgbToSaturation(r: Int, g: Int, b: Int) -> Float {
        let R = Float(r) / 255.0
        let G = Float(g) / 255.0
        let B = Float(b) / 255.0

        let maxC = max(R, G, B)
        let minC = min(R, G, B)
        let delta = maxC - minC

        let lightness = (maxC + minC) / 2
        if delta == 0 {
            return 0
        } else {
            return delta / (1 - abs(2 * lightness - 1))
        }
    }

    private func isValidColor(r: Int, g: Int, b: Int) -> Bool {
        let brightness = (r + g + b) / 3
        let maxComponent = max(r, max(g, b))
        let minComponent = min(r, min(g, b))
        let saturation =
            maxComponent > 0
                ? Float(maxComponent - minComponent) / Float(maxComponent) : 0

        if brightness < 50, saturation > 0.1 {
            return true
        }

        if brightness > 240 {
            return false
        }

        // 排除饱和度过低的灰色系
        if saturation < 0.08 {
            return false
        }

        // 排除过于鲜艳的荧光色
        if saturation > 0.95, brightness > 180 {
            return false
        }

        return true
    }

    private func calculateSimpleWeight(x: Int, y: Int, width: Int, height: Int)
        -> Float
    {
        let centerX = Float(width) / 2.0
        let centerY = Float(height) / 2.0
        let fx = Float(x)
        let fy = Float(y)

        // 距离中心越近权重越高，但四个角落也有额外权重
        let distanceFromCenter = sqrt(
            pow(fx - centerX, 2) + pow(fy - centerY, 2),
        )
        let maxDistance = sqrt(pow(centerX, 2) + pow(centerY, 2))
        var weight = 1.0 + (1.0 - distanceFromCenter / maxDistance) * 0.5

        // 给四个角落额外权重
        let isNearCorner =
            (x < width / 4 || x >= width * 3 / 4)
                && (y < height / 4 || y >= height * 3 / 4)
        if isNearCorner {
            weight *= 1.3
        }

        return weight
    }

    private func getSimpleColorQuality(r: Int, g: Int, b: Int) -> Float {
        let maxComponent = max(r, max(g, b))
        let minComponent = min(r, min(g, b))
        let saturation =
            maxComponent > 0
                ? Float(maxComponent - minComponent) / Float(maxComponent) : 0
        let brightness = Float(r + g + b) / 3.0

        var score: Float = 1.0

        if saturation > 0.3 {
            score *= 1.8
        } else if saturation > 0.15 {
            score *= 1.2
        } else if saturation < 0.1 {
            score *= 0.3
        }

        if brightness > 30 && brightness < 230 {
            score *= 1.1
        } else if brightness < 20 || brightness > 240 {
            score *= 0.8
        }

        return score
    }

    private func resizeImage(_ image: NSImage, to size: CGSize) -> NSImage? {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0,
        )
        newImage.unlockFocus()
        return newImage
    }
}
