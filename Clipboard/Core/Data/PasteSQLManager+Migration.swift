import AppKit
import Foundation
import SQLite

// MARK: - unique_id 重算与去重迁移

extension PasteSQLManager {
    private static let uniqueIdMigrationVersion = 1

    private func databaseUserVersion() -> Int {
        guard let connection else { return 0 }
        do {
            let version = try connection.scalar("PRAGMA user_version") as? Int64 ?? 0
            return Int(version)
        } catch {
            log.error("读取数据库版本失败: \(error)")
            return 0
        }
    }

    private func setDatabaseUserVersion(_ version: Int) -> Bool {
        guard let connection else { return false }
        do {
            try connection.run("PRAGMA user_version = \(version)")
            return true
        } catch {
            log.error("更新数据库版本失败: \(error)")
            return false
        }
    }

    private func indexExists(named name: String) -> Bool {
        guard let connection else { return false }
        do {
            let count = try connection.scalar(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name='\(name)'"
            ) as? Int64 ?? 0
            return count > 0
        } catch {
            log.error("读取数据库索引失败: \(error)")
            return false
        }
    }

    /// 历史版本 `generateUniqueId` 算法变更后，旧行存储的 `unique_id` 与运行时重算值不一致：
    /// 既会绕过插入去重产生内容相同的多行，又会让 diffable data source 因重复标识符崩溃。
    /// 本迁移用当前算法重算全表 `unique_id`，合并重复行（保留时间戳最新的），并修正存储值。
    func migrateUniqueIdIfNeeded() async {
        let currentVersion = databaseUserVersion()
        guard currentVersion < Self.uniqueIdMigrationVersion
            || !indexExists(named: "uidx_unique_id")
        else {
            log.debug("unique_id 已迁移，跳过")
            return
        }
        guard await performUniqueIdMigration() else { return }
        if setDatabaseUserVersion(
            max(currentVersion, Self.uniqueIdMigrationVersion)
        ) {
            log.info("unique_id 迁移完成")
        }
    }

    private func readIdentities() async throws -> [PasteIdentity] {
        guard let connection else { return [] }
        var infos: [PasteIdentity] = []
        let query = table.select(Col.id, Col.uniqueId, Col.type, Col.data, Col.timestamp, Col.group)
        for row in try connection.prepare(query) {
            let type = PasteboardType(row[Col.type])
            let correct = await PasteboardModel.generateUniqueId(for: type, data: row[Col.data])
            infos.append(PasteIdentity(
                id: row[Col.id],
                storedUniqueId: row[Col.uniqueId],
                correctUniqueId: correct,
                timestamp: row[Col.timestamp],
                group: row[Col.group]
            ))
        }
        return infos
    }

    private func performUniqueIdMigration() async -> Bool {
        guard connection != nil else { return false }
        log.info("开始重算 unique_id 并清理重复行")

        let infos: [PasteIdentity]
        do {
            infos = try await readIdentities()
        } catch {
            log.error("读取数据失败，跳过 unique_id 迁移: \(error)")
            return false
        }

        var groups: [String: [PasteIdentity]] = [:]
        for info in infos {
            groups[info.correctUniqueId, default: []].append(info)
        }

        var idsToDelete: [Int64] = []
        var updates: [(row: PasteIdentity, group: Int?)] = []

        for (correctId, rows) in groups {
            let sorted = rows.sorted { $0.timestamp > $1.timestamp }
            let keeper = sorted[0]
            idsToDelete.append(contentsOf: sorted.dropFirst().map(\.id))

            // 分组不能丢：保留行为 -1 时继承重复行里最新的非默认分组，仅在此时才写 group
            let mergedGroup = sorted.first(where: { $0.group != -1 })?.group
            let needGroupUpdate = mergedGroup != nil && mergedGroup != keeper.group
            if keeper.storedUniqueId != correctId || needGroupUpdate {
                updates.append((keeper, needGroupUpdate ? mergedGroup : nil))
            }
        }

        guard !idsToDelete.isEmpty || !updates.isEmpty else {
            log.info("unique_id 无需迁移")
            return true
        }

        return applyIdentities(deleting: idsToDelete, updates: updates)
    }

    private func applyIdentities(
        deleting idsToDelete: [Int64],
        updates: [(row: PasteIdentity, group: Int?)]
    ) -> Bool {
        guard let connection else { return false }
        do {
            try connection.run("BEGIN TRANSACTION")
            for id in idsToDelete {
                try connection.run(table.filter(Col.id == id).delete())
            }
            for update in updates {
                try connection.run(table.filter(Col.id == update.row.id)
                    .update(Col.uniqueId <- "__migrating__\(update.row.id)"))
            }
            for update in updates {
                var setters: [Setter] = [Col.uniqueId <- update.row.correctUniqueId]
                if let group = update.group {
                    setters.append(Col.group <- group)
                }
                try connection.run(table.filter(Col.id == update.row.id).update(setters))
            }
            try connection.run("COMMIT")
            log.info("unique_id 迁移：删除重复 \(idsToDelete.count) 行，修正 \(updates.count) 行")
            return true
        } catch {
            _ = try? connection.run("ROLLBACK")
            log.error("unique_id 迁移失败: \(error)")
            return false
        }
    }
}
