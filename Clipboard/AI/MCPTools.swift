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
        let disabled = MCPDisabledTools.load()
        return allDefinitions.filter { ($0["name"] as? String).map { !disabled.contains($0) } ?? true }
    }

    private static var inputSchemas: [String: [String: Any]] {
        [
            "search_clipboard": [
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "Keyword matched against item content. Punctuation and whitespace are ignored."
                    ],
                    "type": [
                        "type": "string",
                        "enum": ["text", "link", "image", "file", "color"],
                        "description": "Item type filter. `text` covers both plain and rich text."
                    ],
                    "tag": [
                        "type": "string",
                        "description": "Tag name filter (from list_tags), case-insensitive."
                    ],
                    "app": [
                        "type": "string",
                        "description": "Source application filter: case-insensitive substring of the `app` field."
                    ],
                    "date_from": [
                        "type": "string",
                        "description": """
                            ISO-8601 start (inclusive), e.g. 2026-05-01T08:00:00+08:00. \
                            A date-only value starts at the beginning of that day in the user's time zone.
                            """
                    ],
                    "date_to": [
                        "type": "string",
                        "description": """
                            ISO-8601 end (exclusive). A date-only value covers that whole day \
                            in the user's time zone.
                            """
                    ],
                    "limit": [
                        "type": "integer",
                        "minimum": 1,
                        "maximum": MCPTools.maxSearchLimit,
                        "description": "Maximum number of items, default 20, max \(MCPTools.maxSearchLimit)."
                    ]
                ]
            ],
            "read_item": [
                "type": "object",
                "properties": [
                    "id": ["type": "string", "description": "Item id from search_clipboard."],
                    "max_chars": [
                        "type": "integer",
                        "minimum": 1,
                        "maximum": MCPTools.maxReadChars,
                        "description": """
                            Maximum characters of text to return, default \(MCPTools.defaultReadChars), \
                            max \(MCPTools.maxReadChars).
                            """
                    ]
                ],
                "required": ["id"]
            ],
            "write_clipboard": [
                "type": "object",
                "properties": [
                    "content": ["type": "string", "description": "Plain text to write"]
                ],
                "required": ["content"]
            ],
            "list_tags": [
                "type": "object",
                "properties": [:]
            ]
        ]
    }

    private static var allDefinitions: [[String: Any]] {
        let schemas = inputSchemas
        return MCPToolDefinition.all.compactMap { def in
            guard let schema = schemas[def.name] else { return nil }
            return [
                "name": def.name,
                "description": def.description,
                "inputSchema": schema,
                "annotations": [
                    "readOnlyHint": def.isReadOnly,
                    "destructiveHint": false,
                    "idempotentHint": def.isReadOnly,
                    "openWorldHint": false
                ]
            ]
        }
    }

    // MARK: - Dispatch

    func call(params: [String: Any]) -> [String: Any] {
        guard FileManager.default.fileExists(atPath: ClipboardPaths.mcpEnableFlag) else {
            return mcpError("MCP is disabled. Enable it in Clip → Settings → AI.")
        }
        guard let name = params["name"] as? String else {
            return mcpError("Invalid tool call params")
        }
        // 无参数工具的客户端可能省略 arguments
        let arguments = params["arguments"] as? [String: Any] ?? [:]

        guard !MCPDisabledTools.load().contains(name) else {
            return mcpError("Tool \(name) is disabled in Clip → Settings → AI.")
        }

        switch name {
        case "search_clipboard": return searchClipboard(arguments)
        case "read_item": return readItem(arguments)
        case "write_clipboard": return writeClipboard(arguments)
        case "list_tags": return listTags()
        default: return mcpError("Unknown tool: \(name)")
        }
    }

    // MARK: - write_clipboard

    private func writeClipboard(_ args: [String: Any]) -> [String: Any] {
        guard let content = args["content"] as? String else {
            return mcpError("content is required")
        }
        guard content.count <= 1_000_000 else {
            return mcpError("Content exceeds 1 MB limit")
        }

        NSPasteboard.copy(content)

        guard let contentData = content.data(using: .utf8) else {
            return mcpError("Failed to encode content")
        }

        let uniqueId = contentData.sha256Hex
        let timestamp = Int64(Date().timeIntervalSince1970)
        let showData = String(content.prefix(300)).data(using: .utf8)

        guard let database = try? Connection(ClipboardPaths.database) else {
            return mcpError("Cannot open clipboard database")
        }
        try? database.execute("PRAGMA journal_mode=WAL")
        database.busyTimeout = 5.0

        let table = Table("Clip")

        let existing = table.select(Col.id).filter(Col.uniqueId == uniqueId)
        if let row = try? database.pluck(existing), let existingId = try? row.get(Col.id) {
            _ = try? database.run(
                table.filter(Col.id == existingId)
                    .update(Col.timestamp <- timestamp, Col.hidden <- 0, Col.sortOrder <- Col.nextSortOrder)
            )
            return ["content": [["type": "text", "text": "Clipboard updated"]]]
        }

        let appPath = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ClipboardPaths.appBundleId)?.path ?? ""
        guard
            let appID = try? SourceAppSQL.resolve(
                name: "Clip", path: appPath,
                bundleID: ClipboardPaths.appBundleId, on: database)
        else {
            return mcpError("Cannot resolve source application")
        }
        let insert = table.insert(
            Col.uniqueId <- uniqueId,
            Col.type <- NSPasteboard.PasteboardType.string.rawValue,
            Col.data <- contentData,
            Col.showData <- showData,
            Col.timestamp <- timestamp,
            Col.sortOrder <- Col.nextSortOrder,
            Col.appID <- appID,
            Col.searchText <- content.trimmingCharacters(in: .whitespacesAndNewlines),
            Col.length <- content.count,
            Col.group <- -1,
            Col.tag <- tagValue(for: content),
            Col.hidden <- 0
        )

        if (try? database.run(insert)) != nil {
            return ["content": [["type": "text", "text": "Written to clipboard"]]]
        }
        return mcpError("Failed to write to database")
    }

}

// MARK: - Helpers

nonisolated extension MCPTools {
    static let maxSearchLimit = 100
    static let defaultReadChars = 20_000
    static let maxReadChars = 100_000

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

    private func tagValue(for text: String) -> String {
        if let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
            return "link"
        }
        return "string"
    }
}

// MARK: - Minimal category chip for reading app UserDefaults

nonisolated struct MCPCategoryChip: Codable {
    let id: Int
    let name: String
}
