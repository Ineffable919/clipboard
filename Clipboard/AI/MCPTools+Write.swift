//
//  MCPTools+Write.swift
//  Clipboard
//
//  Created by crown on 2026/11/17
//

import Foundation
import SQLite

/// 写操作工具：在 MCP 线程解析参数，经 MCPStoreBridge 在主线程修改数据，再重新查询生成摘要
nonisolated extension MCPTools {
    // MARK: - Items

    func saveItem(_ args: [String: Any]) async -> [String: Any] {
        await reply {
            let content = try text(args["content"], name: "content")
            let tagId = try (args["tag"] as? String).flatMap { $0.isEmpty ? nil : try resolveTag($0).id }
            let id = try await MCPStoreBridge.saveText(content, tagId: tagId)
            return try summaries(forIds: [id])[0]
        }
    }

    func copyItem(_ args: [String: Any]) async -> [String: Any] {
        await reply {
            let id = try itemId(args["id"])
            try await MCPStoreBridge.copyItem(id: id)
            return try summaries(forIds: [id])[0]
        }
    }

    func updateItem(_ args: [String: Any]) async -> [String: Any] {
        await reply {
            let id = try itemId(args["id"])
            let content = try text(args["content"], name: "content")
            try await MCPStoreBridge.updateText(id: id, text: content)
            return try summaries(forIds: [id])[0]
        }
    }

    func setItemTag(_ args: [String: Any]) async -> [String: Any] {
        await reply {
            let ids = try itemIds(args["ids"])
            let raw = try text(args["tag"], name: "tag")
            let tagId = raw.localizedCaseInsensitiveCompare("none") == .orderedSame ? -1 : try resolveTag(raw).id
            try await MCPStoreBridge.setTag(ids: ids, tagId: tagId)
            return ["items": try summaries(forIds: ids)]
        }
    }

    /// 两步删除：未确认时只返回预览
    func deleteItems(_ args: [String: Any]) async -> [String: Any] {
        await reply {
            let ids = try itemIds(args["ids"])
            let items = try summaries(forIds: ids)
            guard args["confirm"] as? Bool == true else {
                return [
                    "preview": true,
                    "items": items,
                    "message": """
                        Preview only: these \(items.count) item(s) would be permanently deleted. \
                        Call again with confirm: true to delete.
                        """
                ]
            }
            try await MCPStoreBridge.deleteItems(ids: ids)
            return ["deleted": items.count, "ids": ids.map { String($0) }]
        }
    }

    // MARK: - Tags

    func createTag(_ args: [String: Any]) async -> [String: Any] {
        await reply {
            let name = try text(args["name"], name: "name")
            let id = try await MCPStoreBridge.createTag(name: name)
            return try tagSummary(id: id)
        }
    }

    func renameTag(_ args: [String: Any]) async -> [String: Any] {
        await reply {
            let tag = try resolveTag(try text(args["tag"], name: "tag"))
            let name = try text(args["name"], name: "name")
            try await MCPStoreBridge.renameTag(id: tag.id, name: name)
            return try tagSummary(id: tag.id)
        }
    }

    /// 两步删除：未确认时只返回预览；标签内条目保留并回到历史
    func deleteTag(_ args: [String: Any]) async -> [String: Any] {
        await reply {
            let tag = try resolveTag(try text(args["tag"], name: "tag"))
            let summary = try tagSummary(id: tag.id)
            guard args["confirm"] as? Bool == true else {
                return [
                    "preview": true,
                    "tag": summary,
                    "message": """
                        Preview only: tag "\(tag.name)" would be deleted; its items stay in clipboard history. \
                        Call again with confirm: true to delete.
                        """
                ]
            }
            try await MCPStoreBridge.deleteTag(id: tag.id)
            return ["deleted": true, "tag": summary]
        }
    }
}

// MARK: - Helpers

private nonisolated extension MCPTools {
    /// 统一把参数错误转换成 isError 结果
    func reply(_ body: () async throws -> [String: Any]) async -> [String: Any] {
        do {
            return jsonResult(try await body())
        } catch let error as MCPArgumentError {
            return mcpError(error.message)
        } catch {
            return mcpError(error.localizedDescription)
        }
    }

    func text(_ value: Any?, name: String) throws(MCPArgumentError) -> String {
        guard let text = value as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MCPArgumentError(message: "`\(name)` is required and cannot be empty.")
        }
        if name == "content", text.utf8.count > Self.maxWriteBytes {
            throw MCPArgumentError(message: "`content` exceeds the 1 MB limit.")
        }
        return text
    }

    func tagSummary(id: Int) throws(MCPArgumentError) -> [String: Any] {
        guard let tag = userTags().first(where: { $0.id == id }) else {
            throw MCPArgumentError(message: "Tag \(id) not found. Use list_tags to see available tags.")
        }
        var count: Int64 = 0
        if let database = openDatabase(),
            let value = try? database.scalar(#"SELECT COUNT(*) FROM Clip WHERE "group" = ?"#, Int64(id)) as? Int64
        {
            count = value
        }
        return ["id": String(tag.id), "name": tag.name, "itemCount": count]
    }
}
