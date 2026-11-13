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
        case "write_clipboard": .mcpToolWriteClipboard
        case "list_tags": .mcpToolListCategories
        default: LocalizedStringResource(String.LocalizationValue(description))
        }
    }
}
