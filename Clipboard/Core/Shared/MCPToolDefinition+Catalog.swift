//
//  MCPToolDefinition+Catalog.swift
//  Clipboard
//
//  Created by crown on 2026/11/17
//

import Foundation

/// MCP 工具清单；description 面向 AI，不做本地化（设置页另有本地化说明）
nonisolated extension MCPToolDefinition {
    static let readTools: [MCPToolDefinition] = [
        .init(
            name: "search_clipboard",
            description: """
                Search the user's saved clipboard items (history and tagged items) with optional filters. \
                With no arguments, returns the most recent items. Filters combine: `query` (keyword matched \
                against content; punctuation and whitespace are ignored), `type`, `tag` (id or name from \
                list_tags), `app` (case-insensitive substring of the source app name), and \
                `date_from` / `date_to` (ISO-8601, half-open range). Returns `{hasMore, items}` where each \
                item is a summary (id, type, preview, length, timestamp, app, tag); call read_item with the \
                id for full content. Previews that look like secrets (API keys, tokens) are masked and \
                marked `sensitive: true`; read_item returns them in full. Ordered newest first.
                """,
            effect: .readOnly
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
            effect: .readOnly
        ),
        .init(
            name: "list_tags",
            description: """
                List the content types and the user's tags with their ids and item counts, \
                for filtering search_clipboard by `type` or `tag`.
                """,
            effect: .readOnly
        )
    ]

    static let writeTools: [MCPToolDefinition] = [
        .init(
            name: "write_clipboard",
            description: """
                Put plain text on the system clipboard, replacing what the user currently has copied. \
                Clip records it in history like any other copy. To save text without touching the \
                clipboard, use save_item.
                """,
            effect: .additive
        ),
        .init(
            name: "save_item",
            description: """
                Save text as a new item in clipboard history without touching the system clipboard. \
                Optionally put it in a tag (`tag`: id or name from list_tags). Saving text that is already \
                in history moves the existing item to the top instead of duplicating it. The type is \
                auto-detected (text, link or color). Returns the item summary.
                """,
            effect: .additive
        ),
        .init(
            name: "copy_item",
            description: """
                Put a saved item (any type: text, link, color, image or files) back on the system clipboard \
                so the user can paste it, and move it to the top of history. Returns the item summary.
                """,
            effect: .idempotent
        ),
        .init(
            name: "update_item",
            description: """
                Replace the content of a text, link or color item with new plain text (formatting is \
                dropped) and re-detect its type. Image and file items cannot be edited. \
                Returns the updated item summary.
                """,
            effect: .idempotent
        ),
        .init(
            name: "set_item_tag",
            description: """
                Put items in a tag (`tag`: id or name from list_tags), or take them out of their tag with \
                `tag: "none"`. An item belongs to at most one tag. Items only kept in a tag \
                (`inHistory: false`) return to history when taken out. One unknown id fails the call and \
                changes nothing. Returns the item summaries.
                """,
            effect: .idempotent
        ),
        .init(
            name: "create_tag",
            description: "Create a new tag with the given name. Returns the tag summary (id, name, itemCount).",
            effect: .additive
        ),
        .init(
            name: "rename_tag",
            description: "Rename a tag (`tag`: id or name from list_tags). Returns the updated tag summary.",
            effect: .idempotent
        ),
        .init(
            name: "delete_items",
            description: """
                Delete items from clipboard history and their tags, permanently. Two-step: call without \
                `confirm` to preview the items, then with `confirm: true` to delete them. One unknown id \
                fails the call and deletes nothing. To only take items out of a tag, use set_item_tag.
                """,
            effect: .destructive
        ),
        .init(
            name: "delete_tag",
            description: """
                Delete a tag (`tag`: id or name from list_tags). Its items are kept and return to clipboard \
                history. Two-step: call without `confirm` to preview, then with `confirm: true` to delete.
                """,
            effect: .destructive
        )
    ]
}
