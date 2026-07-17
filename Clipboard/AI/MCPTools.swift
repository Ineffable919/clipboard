import AppKit
import CryptoKit
import Foundation
import SQLite

struct MCPTools {
    // MARK: - Tool schema (returned by tools/list)

    static var definitions: [[String: Any]] {
        guard FileManager.default.fileExists(atPath: ClipboardPaths.mcpEnableFlag) else { return [] }
        let disabled = MCPDisabledTools.load()
        return allDefinitions.filter { ($0["name"] as? String).map { !disabled.contains($0) } ?? true }
    }

    private static let inputSchemas: [String: [String: Any]] = [
        "search_clipboard": [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "Search keyword (optional if filtering by type or tag)",
                ],
                "type": [
                    "type": "string",
                    "enum": ["text", "link", "image", "file", "color", "rich"],
                    "description": "Filter by content type: text (plain text), link (URL), image (PNG/TIFF), file (file path), color (hex color), rich (formatted/RTF text)",
                ],
                "tag": [
                    "type": "string",
                    "description": "Filter by user-defined tag name. Call list_tags first to see available names.",
                ],
                "limit": ["type": "integer", "description": "Max results, default 20, max 50"],
            ],
        ],
        "write_clipboard": [
            "type": "object",
            "properties": [
                "content": ["type": "string", "description": "Plain text to write"],
            ],
            "required": ["content"],
        ],
        "list_tags": [
            "type": "object",
            "properties": [:],
        ],
    ]

    private static let allDefinitions: [[String: Any]] = MCPToolDefinition.all.compactMap { def in
        guard let schema = inputSchemas[def.name] else { return nil }
        return ["name": def.name, "description": def.description, "inputSchema": schema]
    }

    // MARK: - Dispatch

    func call(params: [String: Any]) -> [String: Any] {
        guard FileManager.default.fileExists(atPath: ClipboardPaths.mcpEnableFlag) else {
            return mcpError("MCP is disabled. Enable it in Clipboard → Settings → AI.")
        }
        guard let name = params["name"] as? String,
              let arguments = params["arguments"] as? [String: Any]
        else {
            return mcpError("Invalid tool call params")
        }

        guard !MCPDisabledTools.load().contains(name) else {
            return mcpError("Tool \(name) is disabled.")
        }

        switch name {
        case "search_clipboard": return searchClipboard(arguments)
        case "write_clipboard": return writeClipboard(arguments)
        case "list_tags": return listTags()
        default: return mcpError("Unknown tool: \(name)")
        }
    }

    // MARK: - search_clipboard

    private func searchClipboard(_ args: [String: Any]) -> [String: Any] {
        let query = args["query"] as? String ?? ""
        let typeFilter = args["type"] as? String
        let tagName = args["tag"] as? String
        let limit = min(args["limit"] as? Int ?? 20, 50)

        guard !query.isEmpty || typeFilter != nil || tagName != nil else {
            return mcpError("Provide at least one of: query, type, or tag")
        }

        guard let db = try? Connection(ClipboardPaths.database, readonly: true) else {
            return mcpError("Cannot open clipboard database")
        }

        let table = Table("Clip")
        var queryExpr = table
            .select(Col.type, Col.data, Col.searchText, Col.ts, Col.tag)
            .filter(Col.hidden == 0)
            .order(Col.ts.desc)
            .limit(limit)

        if !query.isEmpty {
            queryExpr = queryExpr.filter(Col.searchText.like("%\(query)%"))
        }

        if let typeFilter {
            queryExpr = queryExpr.filter(Col.tag == tagForType(typeFilter))
        }

        if let tagName {
            guard let groupId = resolveCategory(name: tagName) else {
                return mcpError("Tag \"\(tagName)\" not found. Use list_tags to see available tags.")
            }
            queryExpr = queryExpr.filter(Col.group == groupId)
        }

        var contentBlocks: [[String: Any]] = []
        var count = 0

        if let rows = try? db.prepare(queryExpr) {
            for row in rows {
                if count > 0 {
                    contentBlocks.append(["type": "text", "text": "---"])
                }

                let type = (try? row.get(Col.type)) ?? ""
                let tag = (try? row.get(Col.tag)) ?? ""
                let ts = (try? row.get(Col.ts)) ?? 0
                let date = Date(timeIntervalSince1970: TimeInterval(ts))
                    .formatted(date: .abbreviated, time: .shortened)
                let typeLabel = labelForTag(tag)
                let header = "[\(typeLabel)] \(date)"

                if tag == "image" {
                    contentBlocks.append(["type": "text", "text": header])
                    if let data = try? row.get(Col.data) {
                        let mimeType = type == "public.tiff" ? "image/tiff" : "image/png"
                        contentBlocks.append([
                            "type": "image",
                            "data": data.base64EncodedString(),
                            "mimeType": mimeType,
                        ])
                    }
                } else {
                    let body = extractText(from: row, type: type)
                    contentBlocks.append(["type": "text", "text": "\(header)\n\(body)"])
                }

                count += 1
            }
        }

        if contentBlocks.isEmpty {
            let desc = query.isEmpty ? "with current filters" : "for \"\(query)\""
            return ["content": [["type": "text", "text": "No results \(desc)"]]]
        }

        return ["content": contentBlocks]
    }

    // MARK: - list_tags

    private func listTags() -> [String: Any] {
        var lines: [String] = []

        lines.append("Content types (use the 'type' parameter):")
        for t in ["text", "rich", "link", "image", "file", "color"] {
            lines.append("  \(t)")
        }

        let userDefaults = UserDefaults(suiteName: ClipboardPaths.appBundleId)
        if let data = userDefaults?.data(forKey: "userCategoryChip"),
           let chips = try? JSONDecoder().decode([MCPCategoryChip].self, from: data),
           !chips.isEmpty
        {
            lines.append("")
            lines.append("User-defined tags (use the 'tag' parameter):")
            for chip in chips {
                lines.append("  \(chip.name)")
            }
        } else {
            lines.append("")
            lines.append("No user-defined tags.")
        }

        return ["content": [["type": "text", "text": lines.joined(separator: "\n")]]]
    }

    // MARK: - write_clipboard

    private func writeClipboard(_ args: [String: Any]) -> [String: Any] {
        guard let content = args["content"] as? String else {
            return mcpError("content is required")
        }
        guard content.count <= 1_000_000 else {
            return mcpError("Content exceeds 1 MB limit")
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)

        guard let contentData = content.data(using: .utf8) else {
            return mcpError("Failed to encode content")
        }

        let uniqueId = contentData.sha256Hex
        let timestamp = Int64(Date().timeIntervalSince1970)
        let showData = String(content.prefix(300)).data(using: .utf8)

        guard let db = try? Connection(ClipboardPaths.database) else {
            return mcpError("Cannot open clipboard database")
        }
        try? db.execute("PRAGMA journal_mode=WAL")
        db.busyTimeout = 5.0

        let table = Table("Clip")

        let existing = table.select(Col.id).filter(Col.uniqueId == uniqueId)
        if let row = try? db.pluck(existing), let existingId = try? row.get(Col.id) {
            _ = try? db.run(
                table.filter(Col.id == existingId)
                    .update(Col.ts <- timestamp, Col.hidden <- 0)
            )
            return ["content": [["type": "text", "text": "Clipboard updated"]]]
        }

        let insert = table.insert(
            Col.uniqueId <- uniqueId,
            Col.type <- NSPasteboard.PasteboardType.string.rawValue,
            Col.data <- contentData,
            Col.showData <- showData,
            Col.ts <- timestamp,
            Col.appPath <- "",
            Col.appName <- "AI",
            Col.searchText <- content.trimmingCharacters(in: .whitespacesAndNewlines),
            Col.length <- content.count,
            Col.group <- -1,
            Col.tag <- tagValue(for: content),
            Col.hidden <- 0
        )

        if (try? db.run(insert)) != nil {
            return ["content": [["type": "text", "text": "Written to clipboard"]]]
        }
        return mcpError("Failed to write to database")
    }

    // MARK: - Helpers

    private func tagForType(_ type: String) -> String {
        switch type {
        case "text": "string"
        case "rich": "rich"
        case "link": "link"
        case "image": "image"
        case "file": "file"
        case "color": "color"
        default: type
        }
    }

    private func labelForTag(_ tag: String) -> String {
        switch tag {
        case "string": "Text"
        case "rich": "Rich Text"
        case "link": "Link"
        case "image": "Image"
        case "file": "File"
        case "color": "Color"
        default: "Text"
        }
    }

    private func extractText(from row: Row, type: String) -> String {
        guard let data = try? row.get(Col.data) else {
            return (try? row.get(Col.searchText)) ?? ""
        }

        switch type {
        case "public.rtf":
            return NSAttributedString(rtf: data, documentAttributes: nil)?.string ?? ""
        case "com.apple.rtfd":
            return NSAttributedString(rtfd: data, documentAttributes: nil)?.string ?? ""
        default:
            return String(data: data, encoding: .utf8) ?? ""
        }
    }

    private func resolveCategory(name: String) -> Int? {
        let userDefaults = UserDefaults(suiteName: ClipboardPaths.appBundleId)
        guard let data = userDefaults?.data(forKey: "userCategoryChip"),
              let chips = try? JSONDecoder().decode([MCPCategoryChip].self, from: data)
        else { return nil }
        return chips.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }?.id
    }

    private func tagValue(for text: String) -> String {
        if let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
            return "link"
        }
        return "string"
    }

    private func mcpError(_ message: String) -> [String: Any] {
        ["content": [["type": "text", "text": message]], "isError": true]
    }
}

// MARK: - Minimal category chip for reading app UserDefaults

private struct MCPCategoryChip: Codable {
    let id: Int
    let name: String
}

// MARK: - SHA-256 (mirrors Data+Extension.swift, local to clipmcp)

private extension Data {
    var sha256Hex: String {
        SHA256.hash(data: self).reduce(into: "") { $0 += String(format: "%02hhx", $1) }
    }
}
