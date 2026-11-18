//
//  MCPTools.swift
//  Clipboard
//
//  Created by crown on 2026/6/2
//

import AppKit
import Foundation
import SQLite

nonisolated struct MCPTools {
    // MARK: - Tool schema (returned by tools/list)

    static var definitions: [[String: Any]] {
        guard FileManager.default.fileExists(atPath: ClipboardPaths.mcpEnableFlag) else { return [] }
        let schemas = MCPToolSchemas.all
        return MCPToolDefinition.all.compactMap { def in
            guard let schema = schemas[def.name] else { return nil }
            return [
                "name": def.name,
                "description": def.description,
                "inputSchema": schema,
                "annotations": def.annotations
            ]
        }
    }

    // MARK: - Dispatch

    func call(params: [String: Any]) async -> [String: Any] {
        guard FileManager.default.fileExists(atPath: ClipboardPaths.mcpEnableFlag) else {
            return mcpError("MCP is disabled. Enable it in Clip → Settings → AI.")
        }
        guard let name = params["name"] as? String else {
            return mcpError("Invalid tool call params")
        }
        // 无参数工具的客户端可能省略 arguments
        let arguments = params["arguments"] as? [String: Any] ?? [:]

        if let result = callReadTool(name, arguments) {
            return result
        }
        return await callWriteTool(name, arguments)
    }

    private func callReadTool(_ name: String, _ arguments: [String: Any]) -> [String: Any]? {
        switch name {
        case "search_clipboard": searchClipboard(arguments)
        case "read_item": readItem(arguments)
        case "list_tags": listTags()
        case "write_clipboard": writeClipboard(arguments)
        default: nil
        }
    }

    private func callWriteTool(_ name: String, _ arguments: [String: Any]) async -> [String: Any] {
        switch name {
        case "save_item": await saveItem(arguments)
        case "copy_item": await copyItem(arguments)
        case "update_item": await updateItem(arguments)
        case "set_item_tag": await setItemTag(arguments)
        case "create_tag": await createTag(arguments)
        case "rename_tag": await renameTag(arguments)
        case "delete_items": await deleteItems(arguments)
        case "delete_tag": await deleteTag(arguments)
        default: mcpError("Unknown tool: \(name)")
        }
    }

    // MARK: - write_clipboard

    /// 只写系统剪贴板，由剪贴板监听按正常复制流程入库
    private func writeClipboard(_ args: [String: Any]) -> [String: Any] {
        guard let content = args["content"] as? String, !content.isEmpty else {
            return mcpError("`content` is required.")
        }
        guard content.utf8.count <= Self.maxWriteBytes else {
            return mcpError("`content` exceeds the 1 MB limit.")
        }
        NSPasteboard.copy(content)
        return jsonResult(["copied": true, "length": content.count])
    }
}

// MARK: - Helpers

nonisolated extension MCPTools {
    static let maxSearchLimit = 100
    static let defaultReadChars = 20_000
    static let maxReadChars = 100_000
    static let maxWriteBytes = 1_048_576

    func mcpError(_ message: String) -> [String: Any] {
        ["content": [["type": "text", "text": message]], "isError": true]
    }

    /// 结构化结果：文本块放 JSON 以兼容旧客户端，structuredContent 供新客户端直接解析
    func jsonResult(_ object: [String: Any]) -> [String: Any] {
        let data = try? JSONSerialization.data(
            withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return ["content": [["type": "text", "text": text]], "structuredContent": object]
    }

    /// 只读打开数据库
    func openDatabase() -> Connection? {
        let database = try? Connection(ClipboardPaths.database, readonly: true)
        database?.busyTimeout = 5.0
        return database
    }

    /// 用户自定义标签（系统标签 -1 不在其中）
    ///
    /// MCP 运行在 App 进程内，直接读标准域；以自身 bundle id 作为 suiteName 不受系统支持，会读不到数据
    func userTags() -> [MCPCategoryChip] {
        guard let data = UserDefaults.standard.data(forKey: PrefKey.userCategoryChip.rawValue),
            let chips = try? JSONDecoder().decode([MCPCategoryChip].self, from: data)
        else { return [] }
        return chips
    }

    /// 按 id 或名称（不区分大小写）查找标签，id 优先
    func resolveTag(_ raw: String) throws(MCPArgumentError) -> MCPCategoryChip {
        let key = raw.trimmingCharacters(in: .whitespaces)
        let tags = userTags()
        if let id = Int(key), let tag = tags.first(where: { $0.id == id }) {
            return tag
        }
        if let tag = tags.first(where: { $0.name.localizedCaseInsensitiveCompare(key) == .orderedSame }) {
            return tag
        }
        throw MCPArgumentError(message: "Tag \"\(raw)\" not found. Use list_tags to see available tags.")
    }
}

// MARK: - Minimal category chip for reading app UserDefaults

nonisolated struct MCPCategoryChip: Codable, Sendable {
    let id: Int
    let name: String
}
