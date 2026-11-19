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
}

// MARK: - MCP tool registry

nonisolated struct MCPToolDefinition {
    /// 工具对数据的影响，用于生成 annotations
    enum Effect {
        /// 不修改任何数据
        case readOnly
        /// 修改数据，重复调用结果相同
        case idempotent
        /// 修改数据，重复调用会产生新的结果
        case additive
        /// 不可恢复地删除数据
        case destructive
    }

    let name: String
    let description: String
    let effect: Effect

    var annotations: [String: Bool] {
        [
            "readOnlyHint": effect == .readOnly,
            "destructiveHint": effect == .destructive,
            "idempotentHint": effect == .readOnly || effect == .idempotent,
            "openWorldHint": false
        ]
    }

    static let all: [MCPToolDefinition] = MCPToolDefinition.readTools + MCPToolDefinition.writeTools
}
