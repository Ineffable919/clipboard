//
//  MCPStoreBridge.swift
//  Clipboard
//
//  Created by crown on 2026/11/17
//

import AppKit
import Combine
import SQLite

/// MCP 写操作的主线程入口：统一经 PasteDataStore / CategoryChipStore 修改数据，界面随之刷新
///
/// 参数与返回值只用 Sendable 类型（id、字符串），条目摘要由调用方在 MCP 线程重新查询生成
@MainActor
enum MCPStoreBridge {
    private static var store: PasteDataStore { .main }
    private static var chipStore: CategoryChipStore { .shared }

    // MARK: - Items

    /// 保存文本为新条目；内容已存在时由入库流程移到最前，不会重复
    static func saveText(_ text: String, tagId: Int?) async throws(MCPArgumentError) -> Int64 {
        guard let content = PasteboardTextPreparation.prepareForSave(text) else {
            throw MCPArgumentError(message: "`content` cannot be empty or whitespace only.")
        }
        // 来源记为 Clip 自身：AI 客户端可能是命令行进程，前台应用往往与本次保存无关
        let app: NSRunningApplication? = .current
        let model = PasteboardModel(
            pasteboardType: content.type,
            data: content.data,
            showData: content.showData,
            timestamp: Int64(Date().timeIntervalSince1970),
            appPath: app?.bundleURL?.path ?? "",
            appName: app?.localizedName ?? "",
            searchText: PasteboardModel.normalizeSearchText(content.searchText),
            length: content.length,
            group: tagId ?? -1,
            tag: content.tag,
            uniqueId: content.data.sha256Hex,
            sourceBundleID: app?.bundleIdentifier
        )
        PasteMetadataCache.shared.invalidateTagTypesCache(model)
        await store.insertModel(model)
        guard let id = model.id else {
            throw MCPArgumentError(message: "Failed to save the item.")
        }
        return id
    }

    /// 写回系统剪贴板并移到最前，与在面板中复制一致
    static func copyItem(id: Int64) async throws(MCPArgumentError) {
        let model = try await models(for: [id])[0]
        PasteBoard.main.pasteMultipleData([model], isAttribute: true, showTip: false, copy: true)
    }

    static func updateText(id: Int64, text: String) async throws(MCPArgumentError) {
        let model = try await models(for: [id])[0]
        guard model.pasteboardType.isText() else {
            throw MCPArgumentError(message: "Item \(id) is an image or file item; only text items can be edited.")
        }
        guard let content = PasteboardTextPreparation.prepareForSave(text) else {
            throw MCPArgumentError(message: "`content` cannot be empty or whitespace only.")
        }
        let searchText = PasteboardModel.normalizeSearchText(content.searchText)
        guard await store.updateItemContent(id: id, content: content, searchText: searchText) else {
            throw MCPArgumentError(message: "Failed to update item \(id).")
        }
    }

    /// tagId 为 -1 表示移出标签；仅保留在标签中的条目移出后回到历史，避免变成不可见的孤儿条目
    static func setTag(ids: [Int64], tagId: Int) async throws(MCPArgumentError) {
        let targets = try await models(for: ids)
        for model in targets {
            guard let id = model.id else { continue }
            if model.group != tagId {
                await store.updateItemGroupInDB(id: id, groupId: tagId)
            }
            if tagId == -1, model.hidden {
                await store.sqlManager.updateItemHidden(id: id, hidden: false)
            }
        }
        refreshLoadedItems(ids: Set(ids)) { model in
            model.updateGroup(val: tagId)
            if tagId == -1 { model.updateHidden(val: false) }
        }
    }

    static func deleteItems(ids: [Int64]) async throws(MCPArgumentError) {
        store.deleteItems(try await models(for: ids))
    }

    // MARK: - Tags

    static func createTag(name: String) throws(MCPArgumentError) -> Int {
        let trimmed = try validTagName(name, excluding: nil)
        let userCount = chipStore.chips.filter { !$0.isSystem }.count
        // 跳过调色板第 0 位的灰色（系统标签使用）
        let colorIndex = 1 + userCount % max(CategoryChip.palette.count - 1, 1)
        chipStore.addChip(name: trimmed, colorIndex: colorIndex)
        guard let chip = chipStore.chips.last(where: { $0.name == trimmed && !$0.isSystem }) else {
            throw MCPArgumentError(message: "Failed to create tag \"\(trimmed)\".")
        }
        return chip.id
    }

    static func renameTag(id: Int, name: String) throws(MCPArgumentError) {
        let chip = try userChip(id: id)
        let trimmed = try validTagName(name, excluding: id)
        chipStore.updateChip(chip, name: trimmed)
    }

    /// 先把标签内条目移回历史再删除标签；面板里删除标签会连同条目一起删除，这里刻意保留条目
    static func deleteTag(id: Int) async throws(MCPArgumentError) {
        let chip = try userChip(id: id)
        let rows = await store.sqlManager.search(filter: Col.group == id, select: [Col.id, Col.hidden])
        for row in rows {
            guard let itemId = try? row.get(Col.id) else { continue }
            await store.updateItemGroupInDB(id: itemId, groupId: -1)
            if (try? row.get(Col.hidden)) == 1 {
                await store.sqlManager.updateItemHidden(id: itemId, hidden: false)
            }
        }
        refreshLoadedItems(ids: Set(rows.compactMap { try? $0.get(Col.id) })) { model in
            model.updateGroup(val: -1)
            model.updateHidden(val: false)
        }
        chipStore.removeChip(chip)
    }

    // MARK: - Helpers

    /// 按传入顺序取条目，任一 id 不存在即报错，不做部分修改
    private static func models(for ids: [Int64]) async throws(MCPArgumentError) -> [PasteboardModel] {
        let visible = Col.hidden == 0 || Col.group != -1
        let rows = await store.sqlManager.search(filter: ids.contains(Col.id) && visible)
        let byId = Dictionary(
            await store.mapRows(rows).compactMap { model in model.id.map { ($0, model) } },
            uniquingKeysWith: { first, _ in first }
        )
        return try ids.map { id throws(MCPArgumentError) in
            guard let model = byId[id] else {
                throw MCPArgumentError(
                    message: "No clipboard item found with id \(id). Use search_clipboard to find valid item ids.")
            }
            return model
        }
    }

    /// 同步面板已加载的条目模型，并通知列表刷新
    private static func refreshLoadedItems(ids: Set<Int64>, update: (PasteboardModel) -> Void) {
        let loaded = store.dataList.value.filter { $0.id.map(ids.contains) ?? false }
        guard !loaded.isEmpty else { return }
        loaded.forEach(update)
        store.updateData(with: store.dataList.value, changeType: .update)
    }

    private static func userChip(id: Int) throws(MCPArgumentError) -> CategoryChip {
        guard let chip = chipStore.chips.first(where: { $0.id == id && !$0.isSystem }) else {
            throw MCPArgumentError(message: "Tag \(id) not found. Use list_tags to see available tags.")
        }
        return chip
    }

    private static func validTagName(_ name: String, excluding id: Int?) throws(MCPArgumentError) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MCPArgumentError(message: "`name` cannot be empty.")
        }
        let duplicate = chipStore.chips.contains {
            !$0.isSystem && $0.id != id && $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }
        guard !duplicate else {
            throw MCPArgumentError(message: "A tag named \"\(trimmed)\" already exists.")
        }
        return trimmed
    }
}
