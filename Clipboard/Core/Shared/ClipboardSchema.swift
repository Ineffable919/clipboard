//
//  ClipboardSchema.swift
//  Clipboard
//
//  Created by crown on 2026/6/2
//

import Foundation
import SQLite

// MARK: - Column definitions

struct Col {
    nonisolated static let id = Expression<Int64>("id")
    nonisolated static let uniqueId = Expression<String>("unique_id")
    nonisolated static let type = Expression<String>("type")
    nonisolated static let data = Expression<Data>("data")
    nonisolated static let showData = Expression<Data?>("show_data")
    nonisolated static let timestamp = Expression<Int64>("timestamp")
    nonisolated static let sortOrder = Expression<Int64>("sort_order")
    nonisolated static let nextSortOrder = Expression<Int64>(
        literal: "(SELECT COALESCE(MAX(sort_order), 0) + 1 FROM Clip)"
    )
    nonisolated static let appID = Expression<Int64>("app_id")
    // 仅供旧备份导入使用
    nonisolated static let appPath = Expression<String>("app_path")
    nonisolated static let appName = Expression<String>("app_name")
    nonisolated static let searchText = Expression<String>("search_text")
    nonisolated static let length = Expression<Int>("length")
    nonisolated static let group = Expression<Int>("group")
    nonisolated static let tag = Expression<String?>("tag")
    nonisolated static let hidden = Expression<Int>("hidden")

    private init() {}
}

// MARK: - Shared paths

nonisolated enum ClipboardPaths {
    static let appBundleId = "com.crown.clipboard"

    private static var appSupportDir: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: appBundleId)
    }

    /// ~/Library/Application Support/com.crown.clipboard/Clip.sqlite3
    static var database: String {
        appSupportDir.appending(path: "Clip.sqlite3").path
    }

    /// Presence of this file = MCP enabled. App toggle creates/removes it
    static var mcpEnableFlag: String {
        appSupportDir.appending(path: "mcp_enabled").path
    }

    /// JSON array of disabled tool names
    static var mcpDisabledTools: String {
        appSupportDir.appending(path: "mcp_disabled_tools").path
    }
}

// MARK: - MCP tool registry

nonisolated struct MCPToolDefinition {
    let name: String
    let description: String
    /// 只读工具不修改剪贴板或数据库，客户端可据此免确认调用
    let isReadOnly: Bool

    static let all: [MCPToolDefinition] = [
        .init(
            name: "search_clipboard",
            description: """
                Search the user's saved clipboard items (history and tagged items) with optional filters. \
                With no arguments, returns the most recent items. Filters combine: `query` (keyword matched \
                against content; punctuation and whitespace are ignored), `type`, `tag` (name from \
                list_tags), `app` (case-insensitive substring of the source app name), and \
                `date_from` / `date_to` (ISO-8601, half-open range). Returns `{hasMore, items}` where each \
                item is a summary (id, type, preview, length, timestamp, app, tag); call read_item with the \
                id for full content. Ordered newest first.
                """,
            isReadOnly: true
        ),
        .init(
            name: "read_item",
            description: """
                Read the full content of a clipboard item by id (from search_clipboard). Text comes back \
                verbatim, cut at `max_chars` (default 20000, max 100000) with `truncated` and `totalLength` \
                set when longer; links return their URL; colors return their hex value; files return their \
                paths one per line; images return the image itself as JPEG, downscaled to at most 1024px \
                on the long edge.
                """,
            isReadOnly: true
        ),
        .init(
            name: "write_clipboard",
            description: "Write plain text to the system clipboard. Replaces what the user currently has copied.",
            isReadOnly: false
        ),
        .init(
            name: "list_tags",
            description: """
                List the content types and the user's tags with their ids and item counts, \
                for filtering search_clipboard by `type` or `tag`.
                """,
            isReadOnly: true
        )
    ]
}

// MARK: - Per-tool enable flag

nonisolated enum MCPDisabledTools {
    static func load() -> Set<String> {
        guard let data = FileManager.default.contents(atPath: ClipboardPaths.mcpDisabledTools),
            let names = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(names)
    }

    static func save(_ disabled: Set<String>) {
        guard let data = try? JSONEncoder().encode(Array(disabled)) else { return }
        FileManager.default.createFile(atPath: ClipboardPaths.mcpDisabledTools, contents: data)
    }
}
