import AppKit
import Foundation
import SQLite

extension PasteSQLManager {
    func insert(item: PasteboardModel, timestamp: Int64, group: Int = -1) async -> (Int64, Int?) {
        let existing = await search(
            filter: Col.uniqueId == item.uniqueId,
            select: [Col.id, Col.group],
            order: [],
            limit: 1
        ).first

        if let row = existing,
           let existingId = try? row.get(Col.id) {
            let existingGroup = (try? row.get(Col.group)) ?? -1
            let query = table.filter(Col.id == existingId)
            do {
                var updates: [Setter] = [
                    Col.timestamp <- timestamp, Col.hidden <- 0, Col.sortOrder <- Col.nextSortOrder
                ]
                if group != -1, group != existingGroup {
                    updates.append(Col.group <- group)
                }
                try connection?.run(query.update(updates))
                log.debug("更新时间戳成功：\(existingId)")
            } catch {
                log.error("更新时间戳失败：\(error)")
            }
            let effectiveGroup = group != -1 ? group : existingGroup
            return (existingId, effectiveGroup)
        }

        let insert = await table.insert(
            Col.uniqueId <- item.uniqueId,
            Col.type <- item.pasteboardType.rawValue,
            Col.data <- item.data,
            Col.showData <- item.showData,
            Col.timestamp <- timestamp,
            Col.sortOrder <- Col.nextSortOrder,
            Col.appPath <- item.appPath,
            Col.appName <- item.appName,
            Col.searchText <- item.searchText,
            Col.length <- item.length,
            Col.group <- item.group,
            Col.tag <- item.tag,
            Col.hidden <- item.hidden ? 1 : 0
        )
        do {
            let rowId = try connection?.run(insert)
            log.debug("插入成功：\(String(describing: rowId))")
            return (rowId ?? -1, nil)
        } catch {
            log.error("插入失败：\(error)")
        }
        return (-1, nil)
    }

    func delete(filter: Expression<Bool>) async {
        let query = table.filter(filter)
        do {
            let count = try connection?.run(query.delete())
            log.debug("删除的条数为：\(String(describing: count))")
        } catch {
            log.error("删除失败：\(error)")
        }
    }

    func delete(id: Int64) async {
        let idFilter = table.filter(Col.id == id)
        do {
            try connection?.run(idFilter.delete())
        } catch {
            log.error("删除失败：\(error)，id：\(id)")
        }
    }

    func dropTable() async {
        do {
            let result = try connection?.run(table.drop())
            log.debug("删除所有\(String(describing: result?.columnCount))")
        } catch {
            log.error("删除失败：\(error)")
        }
    }

    func recreateTable() async {
        guard let conn = connection else { return }
        Self.createTable(on: conn, table: table)
        Self.createIndexes(on: conn)
        log.debug("表重新创建成功")
    }

    func update(id: Int64, item: PasteboardModel) async {
        let query = table.filter(Col.id == id)
        let update = await query.update(
            Col.uniqueId <- item.uniqueId,
            Col.type <- item.pasteboardType.rawValue,
            Col.data <- item.data,
            Col.showData <- item.showData,
            Col.timestamp <- item.timestamp,
            Col.appPath <- item.appPath,
            Col.appName <- item.appName,
            Col.searchText <- item.searchText,
            Col.length <- item.length,
            Col.group <- item.group,
            Col.tag <- item.tag,
            Col.hidden <- item.hidden ? 1 : 0
        )
        do {
            let count = try connection?.run(update)
            log.debug("修改成功，影响行数：\(String(describing: count))")
        } catch {
            log.error("修改失败：\(error)")
        }
    }

    func updateItemGroup(id: Int64, groupId: Int) async {
        let query = table.filter(Col.id == id)
        let update = query.update(Col.group <- groupId)
        do {
            let count = try connection?.run(update)
            log.debug("更新项目分组成功，影响行数：\(String(describing: count))")
        } catch {
            log.error("更新项目分组失败：\(error)")
        }
    }

    func updateItemHidden(id: Int64, hidden: Bool) async {
        let query = table.filter(Col.id == id)
        let update = query.update(Col.hidden <- hidden ? 1 : 0)
        do {
            let count = try connection?.run(update)
            log.debug("更新项目 hidden 成功，影响行数：\(String(describing: count))")
        } catch {
            log.error("更新项目 hidden 失败：\(error)")
        }
    }

    func updateItemTag(
        id: Int64,
        expectedTag: String,
        newTag: String
    ) async -> Bool {
        guard let database = connection else { return false }

        let query = table.filter(
            (Col.id == id) && (Col.tag == expectedTag)
        )
        do {
            let count = try database.run(query.update(Col.tag <- newTag))
            guard count > 0 else { return false }
            log.debug("修复项目 tag 成功：\(expectedTag) -> \(newTag)，id：\(id)")
            return true
        } catch {
            log.error("修复项目 tag 失败：\(error)，id：\(id)")
            return false
        }
    }

    func updateItemContent(
        id: Int64,
        content: PasteContent,
        searchText: String
    ) async -> Bool {
        guard let connection else { return false }
        let uniqueId = await PasteboardModel.generateUniqueId(
            for: content.type,
            data: content.data
        )
        let timestamp = Int64(Date().timeIntervalSince1970)

        do {
            guard let currentRow = try connection.pluck(
                table
                    .select(Col.group)
                    .filter(Col.id == id)
            ) else {
                log.error("更新文本内容失败：记录不存在，id：\(id)")
                return false
            }

            let duplicateRow = try connection.pluck(
                table
                    .select(Col.id, Col.group)
                    .filter(Col.uniqueId == uniqueId && Col.id != id)
            )
            let duplicateId = duplicateRow?[Col.id]
            let currentGroup = currentRow[Col.group]
            let duplicateGroup = duplicateRow?[Col.group] ?? -1
            let effectiveGroup =
                currentGroup == -1 ? duplicateGroup : currentGroup

            try connection.run("BEGIN IMMEDIATE TRANSACTION")
            if let duplicateId {
                try connection.run(table.filter(Col.id == duplicateId).delete())
            }

            let setters = contentSetters(content, searchText: searchText, uniqueId: uniqueId, group: effectiveGroup)
            let update = table.filter(Col.id == id).update(setters + [Col.timestamp <- timestamp])
            let count = try connection.run(update)
            guard count == 1 else {
                throw NSError(
                    domain: "PasteSQLManager",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "更新文本内容影响行数异常：\(count)"
                    ]
                )
            }
            try connection.run("COMMIT")
            log.debug("更新文本内容成功：\(id)")
            return true
        } catch {
            _ = try? connection.run("ROLLBACK")
            log.error("更新文本内容失败：\(error)")
            return false
        }
    }
    private func contentSetters(
        _ content: PasteContent,
        searchText: String,
        uniqueId: String,
        group: Int
    ) -> [Setter] {
        [
            Col.uniqueId <- uniqueId,
            Col.type <- content.type.rawValue,
            Col.data <- content.data,
            Col.showData <- content.showData,
            Col.searchText <- searchText,
            Col.length <- content.length,
            Col.group <- group,
            Col.tag <- content.tag,
            Col.sortOrder <- Col.nextSortOrder
        ]
    }

}
