import AppKit
import Foundation
import SQLite

extension PasteSQLManager {
    func getTotalCount() async -> Int {
        do {
            return try connection?.scalar(table.count) ?? 0
        } catch {
            log.error("获取总数失败：\(error)")
            return 0
        }
    }

    func search(
        filter: Expression<Bool>? = nil,
        select: [Expressible]? = nil,
        order: [Expressible]? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) async -> [Row] {
        guard !Task.isCancelled else { return [] }

        let sel =
            select ?? [
                Col.id, Col.uniqueId, Col.type, Col.data, Col.timestamp,
                Col.appID, Col.searchText,
                Col.showData, Col.length, Col.group,
                Col.tag, Col.hidden
            ]
        let ord = order ?? [Col.sortOrder.desc, Col.id.desc]

        var query = table.select(sel).order(ord)
        if let filter {
            query = query.filter(filter)
        }
        if let limit {
            query = query.limit(limit, offset: offset ?? 0)
        }

        do {
            if let result = try connection?.prepare(query) {
                return Array(result)
            }
            return []
        } catch {
            log.error("查询失败：\(error)")
            return []
        }
    }

    func reorderItems(_ ids: [Int64], before: Int64?, after: Int64?) -> [Int64]? {
        guard let database = connection else { return nil }
        do {
            return try PasteOrder.move(ids, before: before, after: after, on: database)
        } catch {
            log.error("保存卡片顺序失败：\(error)")
            return nil
        }
    }

    func orderedItemIDs() -> [Int64]? {
        guard let database = connection else { return nil }
        return try? PasteOrder.orderedIDs(on: database)
    }

    func promoteItems(_ ids: [Int64]) {
        guard let database = connection else { return }
        do {
            try PasteOrder.promote(ids, on: database)
        } catch {
            log.error("置顶卡片失败：\(error)")
        }
    }

    func getDistinctAppInfo() -> [SourceApp] {
        guard let connection else { return [] }
        do {
            let ids = try connection.prepare("""
                SELECT a.id FROM App a
                WHERE EXISTS (SELECT 1 FROM Clip WHERE app_id = a.id)
                ORDER BY MAX(
                    COALESCE((SELECT MAX(timestamp) FROM Clip WHERE app_id = a.id AND hidden = 0), -1),
                    COALESCE((SELECT MAX(timestamp) FROM Clip WHERE app_id = a.id AND hidden = 1), -1)
                ) DESC, a.id DESC
                """).compactMap { $0[0] as? Int64 }
            return ids.compactMap { apps[$0] }
        } catch {
            log.error("获取应用列表失败：\(error)")
            return []
        }
    }

    func getDistinctTags() async -> [String] {
        do {
            var tags: Set<String> = []
            let query = table.select(distinct: Col.tag)
                .filter(Col.tag != nil)

            if let result = try connection?.prepare(query) {
                for row in result {
                    if let tag = try? row.get(Col.tag),
                       !tag.isEmpty {
                        tags.insert(tag)
                    }
                }
            }
            return Array(tags).sorted()
        } catch {
            log.error("获取 tag 列表失败：\(error)")
            return []
        }
    }

    func getCountByGroup(groupId: Int) async -> Int {
        do {
            let query = table.filter(Col.group == groupId)
            return try connection?.scalar(query.count) ?? 0
        } catch {
            log.error("获取分组统计失败：\(error)")
            return 0
        }
    }

    func getCount(filter: Expression<Bool>?) async -> Int {
        do {
            if let filter {
                let query = table.filter(filter)
                return try connection?.scalar(query.count) ?? 0
            } else {
                return try connection?.scalar(table.count) ?? 0
            }
        } catch {
            log.error("获取筛选数量失败：\(error)")
            return 0
        }
    }
}
