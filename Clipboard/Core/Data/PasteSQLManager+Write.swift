import AppKit
import Foundation
import SQLite

extension PasteSQLManager {
    private func resolvedAppID(for item: PasteboardModel) async throws -> Int64 {
        if let id = await item.appID { return id }
        let (name, path, bundleID) = await (item.appName, item.appPath, item.sourceBundleID)
        return try resolveApp(name: name, path: path, bundleID: bundleID)
    }

    func insert(item: PasteboardModel, timestamp: Int64, group: Int = -1) async -> PasteInsertResult {
        let existing = await search(
            filter: Col.uniqueId == item.uniqueId,
            select: [Col.id, Col.group, Col.appID],
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
            return PasteInsertResult(id: existingId, group: effectiveGroup, appID: try? row.get(Col.appID))
        }

        guard let appID = try? await resolvedAppID(for: item) else { return .failed }
        let insert = await table.insert(
            Col.uniqueId <- item.uniqueId,
            Col.type <- item.pasteboardType.rawValue,
            Col.data <- item.data,
            Col.showData <- item.showData,
            Col.timestamp <- timestamp,
            Col.sortOrder <- Col.nextSortOrder,
            Col.appID <- appID,
            Col.searchText <- item.searchText,
            Col.length <- item.length,
            Col.group <- item.group,
            Col.tag <- item.tag,
            Col.hidden <- item.hidden ? 1 : 0
        )
        do {
            let rowId = try connection?.run(insert)
            log.debug("插入成功：\(String(describing: rowId))")
            return PasteInsertResult(id: rowId ?? -1, group: nil, appID: appID)
        } catch {
            log.error("插入失败：\(error)")
        }
        return .failed
    }

    func delete(filter: Expression<Bool>) async {
        let query = table.filter(filter)
        do {
            let count = try connection?.run(query.delete())
            await refreshAppCache()
            log.debug("删除的条数为：\(String(describing: count))")
        } catch {
            log.error("删除失败：\(error)")
        }
    }

    func delete(id: Int64) async {
        let idFilter = table.filter(Col.id == id)
        do {
            try connection?.run(idFilter.delete())
            await refreshAppCache()
        } catch {
            log.error("删除失败：\(error)，id：\(id)")
        }
    }

    /// 无挂起点，清空和空间整理期间同一 actor 上的数据库操作排队执行。
    func clearHistory() throws -> Bool {
        guard let connection else { throw CocoaError(.fileWriteUnknown) }
        try connection.transaction(.immediate) {
            try connection.run(table.delete())
            try connection.run("DELETE FROM App")
        }
        apps.removeAll()
        appIdentities.removeAll()
        do {
            try connection.execute("VACUUM")
            let busy = try connection.scalar("PRAGMA wal_checkpoint(TRUNCATE)") as? Int64
            let backup = URL(filePath: Self.databasePath).deletingLastPathComponent()
                .appending(path: "Clip.before-app-migration.sqlite3")
            if FileManager.default.fileExists(atPath: backup.path) { try FileManager.default.removeItem(at: backup) }
            return busy == 0
        } catch {
            log.error("历史已清空，空间回收失败：\(error)")
            return false
        }
    }

    func update(id: Int64, item: PasteboardModel) async {
        guard let appID = try? await resolvedAppID(for: item) else { return }
        let query = table.filter(Col.id == id)
        let update = await query.update(
            Col.uniqueId <- item.uniqueId,
            Col.type <- item.pasteboardType.rawValue,
            Col.data <- item.data,
            Col.showData <- item.showData,
            Col.timestamp <- item.timestamp,
            Col.appID <- appID,
            Col.searchText <- item.searchText,
            Col.length <- item.length,
            Col.group <- item.group,
            Col.tag <- item.tag,
            Col.hidden <- item.hidden ? 1 : 0
        )
        do {
            let count = try connection?.run(update)
            await refreshAppCache()
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
            let duplicateGroup = duplicateRow?[Col.group] ?? -1
            let effectiveGroup = currentRow[Col.group] == -1 ? duplicateGroup : currentRow[Col.group]

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
            await refreshAppCache()
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
