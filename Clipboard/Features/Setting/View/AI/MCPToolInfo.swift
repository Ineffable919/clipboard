//
//  MCPToolInfo.swift
//  Clipboard
//
//  Created by crown on 2026/8/19
//

import SwiftUI

struct MCPToolInfo: Identifiable {
    var id: String { name }
    let name: String
    let description: LocalizedStringResource

    static let all: [MCPToolInfo] = MCPToolDefinition.all.map {
        .init(
            name: $0.name,
            description: $0.localizedDescription
        )
    }
}

private extension MCPToolDefinition {
    var localizedDescription: LocalizedStringResource {
        switch name {
        case "search_clipboard": .mcpToolSearchClipboard
        case "read_item": .mcpToolReadItem
        case "list_tags": .mcpToolListCategories
        case "write_clipboard": .mcpToolWriteClipboard
        case "save_item": .mcpToolSaveItem
        case "copy_item": .mcpToolCopyItem
        case "update_item": .mcpToolUpdateItem
        case "set_item_tag": .mcpToolSetItemTag
        case "create_tag": .mcpToolCreateTag
        case "rename_tag": .mcpToolRenameTag
        case "delete_items": .mcpToolDeleteItems
        case "delete_tag": .mcpToolDeleteTag
        default: LocalizedStringResource(String.LocalizationValue(description))
        }
    }
}
