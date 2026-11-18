//
//  MCPToolSchemas.swift
//  Clipboard
//
//  Created by crown on 2026/11/17
//

import Foundation

/// 各工具的 inputSchema（tools/list 返回）
nonisolated enum MCPToolSchemas {
    static var all: [String: [String: Any]] {
        [
            "search_clipboard": object([
                "query": string("Keyword matched against item content. Punctuation and whitespace are ignored."),
                "type": [
                    "type": "string",
                    "enum": ["text", "link", "image", "file", "color"],
                    "description": "Item type filter. `text` covers both plain and rich text."
                ],
                "tag": string("Tag id or name (from list_tags); names match case-insensitively."),
                "app": string("Source application filter: case-insensitive substring of the `app` field."),
                "date_from": string("""
                    ISO-8601 start (inclusive), e.g. 2026-05-01T08:00:00+08:00. \
                    A date-only value starts at the beginning of that day in the user's time zone.
                    """),
                "date_to": string("""
                    ISO-8601 end (exclusive). A date-only value covers that whole day in the user's time zone.
                    """),
                "limit": integer(
                    "Maximum number of items, default 20, max \(MCPTools.maxSearchLimit).",
                    max: MCPTools.maxSearchLimit)
            ]),
            "read_item": object(
                [
                    "id": itemId,
                    "max_chars": integer(
                        """
                        Maximum characters of text to return, default \(MCPTools.defaultReadChars), \
                        max \(MCPTools.maxReadChars).
                        """,
                        max: MCPTools.maxReadChars)
                ], required: ["id"]),
            "list_tags": object([:]),
            "write_clipboard": object(
                ["content": string("Plain text to put on the clipboard.")],
                required: ["content"]),
            "save_item": object(
                [
                    "content": string("Text content for the new item, stored verbatim."),
                    "tag": string("Optional tag id or name (from list_tags) to put the item in.")
                ], required: ["content"]),
            "copy_item": object(["id": itemId], required: ["id"]),
            "update_item": object(
                ["id": itemId, "content": string("New plain text content.")],
                required: ["id", "content"]),
            "set_item_tag": object(
                [
                    "ids": itemIds,
                    "tag": string("Tag id or name (from list_tags), or \"none\" to take the items out of their tag.")
                ], required: ["ids", "tag"]),
            "create_tag": object(["name": string("Name for the new tag (whitespace-trimmed).")], required: ["name"]),
            "rename_tag": object(
                [
                    "tag": string("Tag id or name (from list_tags)."),
                    "name": string("New name (whitespace-trimmed).")
                ], required: ["tag", "name"]),
            "delete_items": object(["ids": itemIds, "confirm": confirm], required: ["ids"]),
            "delete_tag": object(
                ["tag": string("Tag id or name (from list_tags)."), "confirm": confirm],
                required: ["tag"])
        ]
    }

    // MARK: - Builders

    private static var itemId: [String: Any] {
        string("Item id (from search_clipboard).")
    }

    private static var itemIds: [String: Any] {
        [
            "type": "array",
            "items": ["type": "string"],
            "minItems": 1,
            "description": "Item ids (from search_clipboard)."
        ]
    }

    private static var confirm: [String: Any] {
        [
            "type": "boolean",
            "description": "Must be true to actually delete. Omit or false to preview only."
        ]
    }

    private static func object(_ properties: [String: Any], required: [String] = []) -> [String: Any] {
        var schema: [String: Any] = ["type": "object", "properties": properties]
        if !required.isEmpty { schema["required"] = required }
        return schema
    }

    private static func string(_ description: String) -> [String: Any] {
        ["type": "string", "description": description]
    }

    private static func integer(_ description: String, max: Int) -> [String: Any] {
        ["type": "integer", "minimum": 1, "maximum": max, "description": description]
    }
}
