import AppKit
import CryptoKit
import Foundation
import SQLite

struct MCPTools {
    // MARK: - Tool schema (returned by tools/list)

    static let definitions: [[String: Any]] = [
        [
            "name": "search_clipboard",
            "description": "Search clipboard history by keyword. Returns matching items with text content, type, and timestamp.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "Search keyword"],
                    "limit": ["type": "integer", "description": "Max results, default 20, max 50"],
                ],
                "required": ["query"],
            ],
        ],
        [
            "name": "write_clipboard",
            "description": "Write plain text to the system clipboard and save it to clipboard history.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "content": ["type": "string", "description": "Plain text to write"],
                ],
                "required": ["content"],
            ],
        ],
    ]

    // MARK: - Dispatch

    func call(params: [String: Any]) -> [String: Any] {
        guard FileManager.default.fileExists(atPath: ClipboardPaths.mcpEnableFlag) else {
            return mcpError("MCP is disabled. Enable it in Clipboard → Settings → MCP.")
        }
        guard let name = params["name"] as? String,
              let arguments = params["arguments"] as? [String: Any]
        else {
            return mcpError("Invalid tool call params")
        }

        switch name {
        case "search_clipboard": return searchClipboard(arguments)
        case "write_clipboard":  return writeClipboard(arguments)
        default:                 return mcpError("Unknown tool: \(name)")
        }
    }

    // MARK: - search_clipboard

    private func searchClipboard(_ args: [String: Any]) -> [String: Any] {
        guard let query = args["query"] as? String, !query.isEmpty else {
            return mcpError("query is required")
        }
        let limit = min(args["limit"] as? Int ?? 20, 50)

        guard let db = try? Connection(ClipboardPaths.database, readonly: true) else {
            return mcpError("Cannot open clipboard database")
        }

        let table = Table("Clip")
        let queryExpr = table
            .select(Col.id, Col.type, Col.showData, Col.searchText, Col.ts)
            .filter(Col.searchText.like("%\(query)%") && Col.hidden == 0)
            .order(Col.ts.desc)
            .limit(limit)

        var lines: [String] = []
        if let rows = try? db.prepare(queryExpr) {
            for row in rows {
                let id = (try? row.get(Col.id)) ?? 0
                let type = (try? row.get(Col.type)) ?? ""
                let ts = (try? row.get(Col.ts)) ?? 0
                let date = Date(timeIntervalSince1970: TimeInterval(ts))
                    .formatted(date: .abbreviated, time: .shortened)

                let content: String
                if let showData = try? row.get(Col.showData),
                   let text = String(data: showData, encoding: .utf8)
                {
                    content = String(text.prefix(300))
                } else {
                    content = String(((try? row.get(Col.searchText)) ?? "").prefix(300))
                }

                lines.append("[\(id)] [\(type)] \(date)\n\(content)")
            }
        }

        let text = lines.isEmpty
            ? "No results for \"\(query)\""
            : lines.joined(separator: "\n\n---\n\n")

        return ["content": [["type": "text", "text": text]]]
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
            return ["content": [["type": "text", "text": "Clipboard updated (id: \(existingId))"]]]
        }

        let insert = table.insert(
            Col.uniqueId  <- uniqueId,
            Col.type      <- NSPasteboard.PasteboardType.string.rawValue,
            Col.data      <- contentData,
            Col.showData  <- showData,
            Col.ts        <- timestamp,
            Col.appPath   <- "",
            Col.appName   <- "AI",
            Col.searchText <- content.trimmingCharacters(in: .whitespacesAndNewlines),
            Col.length    <- content.count,
            Col.group     <- -1,
            Col.tag       <- tagValue(for: content),
            Col.hidden    <- 0
        )

        if let rowId = try? db.run(insert) {
            return ["content": [["type": "text", "text": "Written to clipboard (id: \(rowId))"]]]
        }
        return mcpError("Failed to write to database")
    }

    // MARK: - Helpers

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

// MARK: - SHA-256 (mirrors Data+Extension.swift, local to clip-mcp)

private extension Data {
    var sha256Hex: String {
        SHA256.hash(data: self).reduce(into: "") { $0 += String(format: "%02hhx", $1) }
    }
}
