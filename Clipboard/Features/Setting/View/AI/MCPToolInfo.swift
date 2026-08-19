//
//  MCPToolInfo.swift
//  Clipboard
//

import SwiftUI

struct MCPToolInfo: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let color: Color

    static let all: [MCPToolInfo] = MCPToolDefinition.all.map {
        .init(
            name: $0.name,
            description: $0.localizedDescription,
            icon: $0.icon,
            color: Color(hex: $0.colorHex)
        )
    }
}

private extension MCPToolDefinition {
    var localizedDescription: String {
        switch name {
        case "search_clipboard": String(localized: .mcpToolDescSearchClipboard)
        case "write_clipboard": String(localized: .mcpToolDescWriteClipboard)
        case "list_tags": String(localized: .mcpToolDescListCategories)
        default: description
        }
    }
}
