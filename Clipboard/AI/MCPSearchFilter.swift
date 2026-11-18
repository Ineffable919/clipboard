//
//  MCPSearchFilter.swift
//  Clipboard
//
//  Created by crown on 2026/11/17
//

import Foundation
import SQLite

/// 参数校验失败，message 直接返回给 AI
nonisolated struct MCPArgumentError: Error {
    let message: String
}

/// 把 search_clipboard 的参数转换成 SQL 条件与绑定值（表别名：Clip c，App a）
nonisolated struct MCPSearchFilter {
    /// 可见条目：仍在历史中，或已从历史移除但还保留在某个标签里
    static let visibleClause = #"(c.hidden = 0 OR c."group" != -1)"#

    private(set) var clauses = [Self.visibleClause]
    private(set) var bindings: [Binding?] = []

    var whereClause: String {
        clauses.joined(separator: " AND ")
    }

    /// search_text 入库时已去掉标点与空白，关键词需同样归一化才能匹配；
    /// 归一化后不再含 LIKE 通配符，ESCAPE 仅作兜底
    mutating func addQuery(_ raw: String?) throws(MCPArgumentError) {
        guard let query = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty else { return }
        let keyword = PasteboardModel.normalizeSearchText(query)
        guard !keyword.isEmpty else {
            throw MCPArgumentError(
                message: "`query` has no searchable characters after removing punctuation and whitespace.")
        }
        clauses.append(#"c.search_text LIKE ? ESCAPE '\'"#)
        bindings.append("%\(Self.escapeLike(keyword))%")
    }

    mutating func addType(_ type: String?) throws(MCPArgumentError) {
        guard let type else { return }
        guard let tags = MCPItemReader.tags(forType: type) else {
            throw MCPArgumentError(message: "Unknown `type` \"\(type)\". Allowed: text, link, image, file, color.")
        }
        clauses.append("c.tag IN (\(tags.map { _ in "?" }.joined(separator: ", ")))")
        bindings += tags.map { $0 as Binding? }
    }

    mutating func addTag(_ tag: MCPCategoryChip?) {
        guard let tag else { return }
        clauses.append(#"c."group" = ?"#)
        bindings.append(Int64(tag.id))
    }

    mutating func addIds(_ ids: [Int64]) {
        guard !ids.isEmpty else { return }
        clauses.append("c.id IN (\(ids.map { _ in "?" }.joined(separator: ", ")))")
        bindings += ids.map { $0 as Binding? }
    }

    mutating func addApp(_ app: String?) {
        guard let app, !app.isEmpty else { return }
        clauses.append(#"a.app_name LIKE ? ESCAPE '\'"#)
        bindings.append("%\(Self.escapeLike(app))%")
    }

    /// 半开区间 [from, to)
    mutating func addDateRange(from rawFrom: Any?, to rawTo: Any?) throws(MCPArgumentError) {
        let start = try Self.parseBound(rawFrom, name: "date_from", isEnd: false)
        let end = try Self.parseBound(rawTo, name: "date_to", isEnd: true)
        if let start, let end, start >= end {
            throw MCPArgumentError(message: "`date_from` must be before `date_to`.")
        }
        if let start {
            clauses.append("c.timestamp >= ?")
            bindings.append(Int64(start.timeIntervalSince1970.rounded(.up)))
        }
        if let end {
            clauses.append("c.timestamp < ?")
            bindings.append(Int64(end.timeIntervalSince1970.rounded(.up)))
        }
    }

    // MARK: - Helpers

    /// 解析日期边界；只给日期时按用户时区取当天开始（结束边界取次日开始）
    private static func parseBound(_ value: Any?, name: String, isEnd: Bool) throws(MCPArgumentError) -> Date? {
        guard let raw = (value as? String)?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
            return nil
        }
        if let date = try? Date(raw, strategy: .iso8601) {
            return date
        }
        if let date = try? Date(raw, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
            return date
        }
        let dayStyle = Date.ISO8601FormatStyle(timeZone: .current).year().month().day()
        if let day = try? Date(raw, strategy: dayStyle) {
            return isEnd ? Calendar.current.date(byAdding: .day, value: 1, to: day) : day
        }
        throw MCPArgumentError(message: "`\(name)` must be an ISO-8601 date or date-time: \(raw)")
    }

    /// 转义 LIKE 通配符，配合 `ESCAPE '\'` 使用
    private static func escapeLike(_ text: String) -> String {
        text.replacing("\\", with: "\\\\")
            .replacing("%", with: "\\%")
            .replacing("_", with: "\\_")
    }
}
