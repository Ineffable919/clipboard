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

    /// JSON array of disabled tool names (tools enabled by default)
    static var mcpDisabledTools: String {
        appSupportDir.appending(path: "mcp_disabled_tools").path
    }

    /// JSON array of enabled tool names (tools disabled by default, e.g. destructive ones)
    static var mcpEnabledTools: String {
        appSupportDir.appending(path: "mcp_enabled_tools").path
    }
}

// MARK: - MCP tool registry

nonisolated struct MCPToolDefinition {
    /// 工具对数据的影响程度，决定 annotations 与默认开关
    enum Effect {
        /// 不修改任何数据
        case readOnly
        /// 修改数据，重复调用结果相同
        case idempotent
        /// 修改数据，重复调用会产生新的结果
        case additive
        /// 不可恢复地删除数据，默认关闭
        case destructive
    }

    let name: String
    let description: String
    let effect: Effect

    var isDefaultEnabled: Bool {
        effect != .destructive
    }

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

// MARK: - Per-tool enable state

/// 默认开启的工具记录在「已关闭」列表，默认关闭的工具记录在「已开启」列表，
/// 这样新增工具时按各自默认值生效，无需迁移已有配置
nonisolated enum MCPToolSettings {
    static func enabledNames() -> Set<String> {
        let disabled = load(ClipboardPaths.mcpDisabledTools)
        let optedIn = load(ClipboardPaths.mcpEnabledTools)
        return Set(
            MCPToolDefinition.all
                .filter { $0.isDefaultEnabled ? !disabled.contains($0.name) : optedIn.contains($0.name) }
                .map(\.name)
        )
    }

    static func isEnabled(_ name: String) -> Bool {
        enabledNames().contains(name)
    }

    static func save(enabled: Set<String>) {
        let all = MCPToolDefinition.all
        let disabled = all.filter { $0.isDefaultEnabled && !enabled.contains($0.name) }.map(\.name)
        let optedIn = all.filter { !$0.isDefaultEnabled && enabled.contains($0.name) }.map(\.name)
        write(disabled, to: ClipboardPaths.mcpDisabledTools)
        write(optedIn, to: ClipboardPaths.mcpEnabledTools)
    }

    private static func load(_ path: String) -> Set<String> {
        guard let data = FileManager.default.contents(atPath: path),
            let names = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(names)
    }

    private static func write(_ names: [String], to path: String) {
        guard let data = try? JSONEncoder().encode(names.sorted()) else { return }
        FileManager.default.createFile(atPath: path, contents: data)
    }
}
