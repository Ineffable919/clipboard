// ClipboardSchema.swift
// Shared between App and clipmcp targets.

import Foundation
import SQLite

// MARK: - Column definitions (source of truth for both targets)

struct Col {
    nonisolated static let id = Expression<Int64>("id")
    nonisolated static let uniqueId = Expression<String>("unique_id")
    nonisolated static let type = Expression<String>("type")
    nonisolated static let data = Expression<Data>("data")
    nonisolated static let showData = Expression<Data?>("show_data")
    nonisolated static let ts = Expression<Int64>("timestamp")
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

enum ClipboardPaths {
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

    /// Presence of this file = MCP enabled. App toggle creates/removes it.
    static var mcpEnableFlag: String {
        appSupportDir.appending(path: "mcp_enabled").path
    }

    /// JSON array of disabled tool names.
    static var mcpDisabledTools: String {
        appSupportDir.appending(path: "mcp_disabled_tools").path
    }
}

// MARK: - MCP tool registry (shared between App and clipmcp targets)

struct MCPToolDefinition {
    let name: String
    let description: String
    let icon: String
    let colorHex: String

    static let all: [MCPToolDefinition] = [
        .init(name: "search_clipboard", description: "Search clipboard history by keyword, content type, or user category", icon: "magnifyingglass", colorHex: "#007AFF"),
        .init(name: "write_clipboard",  description: "Write plain text to the system clipboard", icon: "bolt.fill", colorHex: "#34C759"),
        .init(name: "list_tags",  description: "List available content types and user-defined tags for clipboard search", icon: "tag.fill", colorHex: "#FF9500"),
    ]
}

// MARK: - Per-tool enable flag (shared between App and clipmcp targets)

enum MCPDisabledTools {
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
