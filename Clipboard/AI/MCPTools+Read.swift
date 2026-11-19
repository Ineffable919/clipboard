//
//  MCPTools+Read.swift
//  Clipboard
//
//  Created by crown on 2026/11/17
//

import Foundation
import SQLite

/// 只读工具：search_clipboard / read_item / list_tags
nonisolated extension MCPTools {
    // MARK: - search_clipboard

    func searchClipboard(_ args: [String: Any]) -> [String: Any] {
        var filter = MCPSearchFilter()
        let limit = min(max(intArgument(args["limit"]) ?? 20, 1), Self.maxSearchLimit)
        do {
            try filter.addQuery(args["query"] as? String)
            try filter.addType(args["type"] as? String)
            if let tag = args["tag"] as? String, !tag.isEmpty {
                filter.addTag(try resolveTag(tag))
            }
            filter.addApp(args["app"] as? String)
            try filter.addDateRange(from: args["date_from"], to: args["date_to"])
            // 多取一条用于判断 hasMore
            let items = try fetchSummaries(filter, limit: limit + 1)
            return jsonResult(["hasMore": items.count > limit, "items": Array(items.prefix(limit))])
        } catch {
            return mcpError(error.message)
        }
    }

    /// 按 id 取摘要，任一 id 不存在即报错；结果顺序与传入顺序一致
    func summaries(forIds ids: [Int64]) throws(MCPArgumentError) -> [[String: Any]] {
        var filter = MCPSearchFilter()
        filter.addIds(ids)
        let items = try fetchSummaries(filter, limit: ids.count)
        let byId = Dictionary(items.map { ($0["id"] as? String ?? "", $0) }, uniquingKeysWith: { first, _ in first })
        return try ids.map { id throws(MCPArgumentError) in
            guard let item = byId[String(id)] else {
                throw MCPArgumentError(
                    message: "No clipboard item found with id \(id). Use search_clipboard to find valid item ids.")
            }
            return item
        }
    }

    private func fetchSummaries(_ filter: MCPSearchFilter, limit: Int) throws(MCPArgumentError) -> [[String: Any]] {
        let sql = """
            SELECT c.id, c.type, c.tag, c.show_data, c.search_text, c.timestamp, c.length,
                   c."group", c.hidden, a.app_name,
                   CASE WHEN c.tag = 'file' THEN c.data END
            FROM Clip c LEFT JOIN App a ON a.id = c.app_id
            WHERE \(filter.whereClause)
            ORDER BY c.sort_order DESC, c.id DESC
            LIMIT ?
            """
        guard let database = openDatabase() else {
            throw MCPArgumentError(message: "Cannot open clipboard database.")
        }
        let tagNames = Dictionary(userTags().map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        do {
            return try database.prepare(sql, filter.bindings + [Int64(limit)]).map {
                summary(of: $0, tagNames: tagNames)
            }
        } catch {
            throw MCPArgumentError(message: "Search failed: \(error.localizedDescription)")
        }
    }

    /// 行列顺序与 fetchSummaries 的 SELECT 一致
    private func summary(of row: Statement.Element, tagNames: [Int: String]) -> [String: Any] {
        let id = row[0] as? Int64 ?? 0
        let pasteboardType = row[1] as? String ?? ""
        let tag = row[2] as? String
        let showData = (row[3] as? Blob).map { Data($0.bytes) }
        let searchText = row[4] as? String ?? ""
        let length = row[6] as? Int64 ?? 0
        let group = Int(row[7] as? Int64 ?? -1)
        let fileData = (row[10] as? Blob).map { Data($0.bytes) }

        let type = MCPItemReader.publicType(forTag: tag)
        var preview: String
        switch type {
        case "image":
            preview = "[image]"
        case "file":
            preview = fileData.map(MCPItemReader.filePreview(from:)) ?? searchText
        default:
            let text = showData.map { MCPItemReader.text(from: $0, pasteboardType: pasteboardType) } ?? ""
            preview = MCPItemReader.preview(of: text.isEmpty ? searchText : text)
        }

        var item: [String: Any] = [
            "id": String(id),
            "type": type,
            "timestamp": isoString(fromTimestamp: row[5] as? Int64 ?? 0)
        ]
        if type == "text" || type == "link", let masked = MCPSecretMasker.mask(preview) {
            preview = masked
            item["sensitive"] = true
        }
        item["preview"] = preview
        if type == "text", length > 0 { item["length"] = length }
        if let appName = row[9] as? String, !appName.isEmpty { item["app"] = appName }
        if group != -1, let name = tagNames[group] { item["tag"] = name }
        // 已从历史移除、仅保留在标签中的条目
        if (row[8] as? Int64 ?? 0) != 0 { item["inHistory"] = false }
        return item
    }

    // MARK: - read_item

    func readItem(_ args: [String: Any]) -> [String: Any] {
        let id: Int64
        do {
            id = try itemId(args["id"])
        } catch {
            return mcpError(error.message)
        }
        let rawId = String(id)
        let maxChars = min(max(intArgument(args["max_chars"]) ?? Self.defaultReadChars, 1), Self.maxReadChars)

        guard let database = openDatabase() else {
            return mcpError("Cannot open clipboard database.")
        }
        let sql = "SELECT c.type, c.tag, c.data FROM Clip c WHERE c.id = ? AND \(MCPSearchFilter.visibleClause)"
        guard let row = try? database.prepare(sql, id).makeIterator().next(),
            let data = (row[2] as? Blob).map({ Data($0.bytes) })
        else {
            return mcpError("No clipboard item found with id \(rawId). Use search_clipboard to find valid item ids.")
        }
        let pasteboardType = row[0] as? String ?? ""
        let type = MCPItemReader.publicType(forTag: row[1] as? String)

        switch type {
        case "image":
            guard let jpeg = MCPItemReader.jpegThumbnail(from: data) else {
                return mcpError("Failed to decode the image of item \(rawId).")
            }
            return [
                "content": [
                    ["type": "image", "data": jpeg.base64EncodedString(), "mimeType": "image/jpeg"],
                    ["type": "text", "text": #"{"id":"\#(rawId)","type":"image"}"#]
                ]
            ]
        case "file":
            let paths = MCPItemReader.filePaths(from: data)
            return jsonResult(["id": rawId, "type": type, "content": paths.joined(separator: "\n")])
        default:
            var text = MCPItemReader.text(from: data, pasteboardType: pasteboardType)
            if type != "text" {
                text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            var result: [String: Any] = ["id": rawId, "type": type]
            if text.count > maxChars {
                result["content"] = String(text.prefix(maxChars))
                result["truncated"] = true
                result["totalLength"] = text.count
            } else {
                result["content"] = text
            }
            return jsonResult(result)
        }
    }

    // MARK: - list_tags

    func listTags() -> [String: Any] {
        var counts: [Int64: Int64] = [:]
        if let database = openDatabase(),
            let rows = try? database.prepare(
                #"SELECT c."group", COUNT(*) FROM Clip c WHERE c."group" != -1 GROUP BY c."group""#)
        {
            for row in rows {
                if let group = row[0] as? Int64 { counts[group] = row[1] as? Int64 ?? 0 }
            }
        }

        let tags: [[String: Any]] = userTags().map {
            ["id": String($0.id), "name": $0.name, "itemCount": counts[Int64($0.id)] ?? 0]
        }
        return jsonResult([
            "types": ["text", "link", "image", "file", "color"],
            "tags": tags
        ])
    }
}

// MARK: - Argument helpers

nonisolated extension MCPTools {
    /// JSON 数字可能被解析为 Int 或 Double
    func intArgument(_ value: Any?) -> Int? {
        switch value {
        case let int as Int: int
        case let double as Double where double.isFinite: Int(double)
        case let string as String: Int(string)
        default: nil
        }
    }

    func itemId(_ value: Any?) throws(MCPArgumentError) -> Int64 {
        guard let raw = value as? String ?? intArgument(value).map({ String($0) }) else {
            throw MCPArgumentError(message: "`id` is required. Use search_clipboard to find item ids.")
        }
        guard let id = Int64(raw) else {
            throw MCPArgumentError(
                message: "No clipboard item found with id \(raw). Use search_clipboard to find valid item ids.")
        }
        return id
    }

    /// 解析 id 数组并去重，保持原顺序
    func itemIds(_ value: Any?) throws(MCPArgumentError) -> [Int64] {
        guard let raws = value as? [Any], !raws.isEmpty else {
            throw MCPArgumentError(message: "`ids` must be a non-empty array of item ids from search_clipboard.")
        }
        var seen = Set<Int64>()
        return try raws.map { raw throws(MCPArgumentError) in try itemId(raw) }.filter { seen.insert($0).inserted }
    }

    /// 带用户时区偏移的 ISO-8601，便于模型按本地日期理解
    func isoString(fromTimestamp timestamp: Int64) -> String {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
            .formatted(Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: .current))
    }
}
