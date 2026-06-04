//
//  PasteSQLManager.swift
//  Clipboard
//
//  Created by crown on 2025/9/16.
//

import AppKit
import Foundation
import SQLite

// Col is defined in Clipboard/Shared/ClipboardSchema.swift (shared with clipmcp target)

actor PasteSQLManager {
    static let manager = PasteSQLManager()

    private static var databaseDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent(Bundle.main.bundleIdentifier ?? "Clip")
    }

    private static var databasePath: String {
        databaseDirectory.appendingPathComponent("Clip.sqlite3").path
    }

    private var _db: Connection?

    private var db: Connection? {
        _db
    }

    private var table: Table

    private init() {
        let dirPath = Self.databaseDirectory.path
        let fileManager = FileManager.default
        var isDir = ObjCBool(false)
        let dirExists = fileManager.fileExists(atPath: dirPath, isDirectory: &isDir)
        if !dirExists || !isDir.boolValue {
            do {
                try fileManager.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
            } catch {
                log.debug(error.localizedDescription)
            }
        }

        var connection: Connection?
        do {
            let conn = try Connection(Self.databasePath)
            log.info("数据库初始化 - 路径：\(Self.databasePath)")
            conn.busyTimeout = 5.0
            connection = conn
        } catch {
            log.error("Connection Error: \(error)")
        }
        _db = connection

        let tab = Table("Clip")
        table = tab

        if let conn = connection {
            try? conn.execute("PRAGMA journal_mode=WAL")
            Self.createTable(on: conn, table: tab)
        }
    }

    private nonisolated static func createTable(on conn: Connection, table: Table) {
        let statement = table.create(ifNotExists: true, withoutRowid: false) { t in
            t.column(Col.id, primaryKey: true)
            t.column(Col.uniqueId)
            t.column(Col.type)
            t.column(Col.data)
            t.column(Col.showData)
            t.column(Col.ts)
            t.column(Col.appPath)
            t.column(Col.appName)
            t.column(Col.searchText)
            t.column(Col.length)
            t.column(Col.group, defaultValue: -1)
            t.column(Col.tag)
            t.column(Col.hidden, defaultValue: 0)
        }
        do {
            try conn.run(statement)
        } catch {
            log.error("Create Table Error: \(error)")
        }
    }

    func setup() {
        Task {
            performIndexCreation()
            migrateTagFieldAsync()
            migrateHiddenFieldAsync()
            migrateUniqueIdAsync()
        }
    }

    private func performIndexCreation() {
        guard let db else { return }
        do {
            try db.run("CREATE INDEX IF NOT EXISTS idx_app_name ON Clip(app_name)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_tag ON Clip(tag)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_ts ON Clip(timestamp DESC)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_group ON Clip(\"group\")")
            try db.run("CREATE INDEX IF NOT EXISTS idx_unique_id ON Clip(unique_id)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_hidden_ts ON Clip(hidden, timestamp DESC)")
            log.debug("索引初始化成功")
        } catch {
            log.warn("索引已存在或创建失败: \(error)")
        }
    }
}

// MARK: - 数据库操作 对外接口

extension PasteSQLManager {
    func getTotalCount() async -> Int {
        do {
            return try db?.scalar(table.count) ?? 0
        } catch {
            log.error("获取总数失败：\(error)")
            return 0
        }
    }

    func insert(item: PasteboardModel, timestamp: Int64, group: Int = -1) async -> (Int64, Int?) {
        let existing = await search(
            filter: Col.uniqueId == item.uniqueId,
            select: [Col.id, Col.group],
            order: [],
            limit: 1
        ).first

        if let row = existing,
           let existingId = try? row.get(Col.id)
        {
            let existingGroup = (try? row.get(Col.group)) ?? -1
            let query = table.filter(Col.id == existingId)
            do {
                var updates: [Setter] = [Col.ts <- timestamp, Col.hidden <- 0]
                if group != -1, group != existingGroup {
                    updates.append(Col.group <- group)
                }
                try db?.run(query.update(updates))
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
            Col.ts <- timestamp,
            Col.appPath <- item.appPath,
            Col.appName <- item.appName,
            Col.searchText <- item.searchText,
            Col.length <- item.length,
            Col.group <- item.group,
            Col.tag <- item.tag,
            Col.hidden <- item.hidden ? 1 : 0
        )
        do {
            let rowId = try db?.run(insert)
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
            let count = try db?.run(query.delete())
            log.debug("删除的条数为：\(String(describing: count))")
        } catch {
            log.error("删除失败：\(error)")
        }
    }

    func delete(id: Int64) async {
        let idFilter = table.filter(Col.id == id)
        do {
            try db?.run(idFilter.delete())
        } catch {
            log.error("删除失败：\(error)，id：\(id)")
        }
    }

    func dropTable() async {
        do {
            let d = try db?.run(table.drop())
            log.debug("删除所有\(String(describing: d?.columnCount))")
        } catch {
            log.error("删除失败：\(error)")
        }
    }

    func recreateTable() async {
        guard let conn = db else { return }
        Self.createTable(on: conn, table: table)
        performIndexCreation()
        log.debug("表重新创建成功")
    }

    func update(id: Int64, item: PasteboardModel) async {
        let query = table.filter(Col.id == id)
        let update = await query.update(
            Col.type <- item.pasteboardType.rawValue,
            Col.data <- item.data,
            Col.showData <- item.showData,
            Col.ts <- item.timestamp,
            Col.appPath <- item.appPath,
            Col.appName <- item.appName,
            Col.searchText <- item.searchText,
            Col.length <- item.length,
            Col.group <- item.group,
            Col.tag <- item.tag,
            Col.hidden <- item.hidden ? 1 : 0
        )
        do {
            let count = try db?.run(update)
            log.debug("修改成功，影响行数：\(String(describing: count))")
        } catch {
            log.error("修改失败：\(error)")
        }
    }

    func updateItemGroup(id: Int64, groupId: Int) async {
        let query = table.filter(Col.id == id)
        let update = query.update(Col.group <- groupId)
        do {
            let count = try db?.run(update)
            log.debug("更新项目分组成功，影响行数：\(String(describing: count))")
        } catch {
            log.error("更新项目分组失败：\(error)")
        }
    }

    func updateItemHidden(id: Int64, hidden: Bool) async {
        let query = table.filter(Col.id == id)
        let update = query.update(Col.hidden <- hidden ? 1 : 0)
        do {
            let count = try db?.run(update)
            log.debug("更新项目 hidden 成功，影响行数：\(String(describing: count))")
        } catch {
            log.error("更新项目 hidden 失败：\(error)")
        }
    }

    func updateItemContent(
        id: Int64,
        type: PasteboardType,
        data: Data,
        showData: Data?,
        searchText: String,
        length: Int,
        tag: String
    ) async {
        let query = table.filter(Col.id == id)
        let timestamp = Int64(Date().timeIntervalSince1970)
        let update = query.update(
            Col.type <- type.rawValue,
            Col.data <- data,
            Col.showData <- showData,
            Col.searchText <- searchText,
            Col.length <- length,
            Col.tag <- tag,
            Col.ts <- timestamp
        )
        do {
            let count = try db?.run(update)
            log.debug("更新文本内容成功，影响行数：\(String(describing: count))")
        } catch {
            log.error("更新文本内容失败：\(error)")
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
                Col.id, Col.type, Col.data, Col.ts,
                Col.appPath, Col.appName, Col.searchText,
                Col.showData, Col.length, Col.group,
                Col.tag, Col.hidden,
            ]
        let ord = order ?? [Col.ts.desc]

        var query = table.select(sel).order(ord)
        if let f = filter { query = query.filter(f) }
        if let l = limit {
            query = query.limit(l, offset: offset ?? 0)
        }

        do {
            if let result = try db?.prepare(query) { return Array(result) }
            return []
        } catch {
            log.error("查询失败：\(error)")
            return []
        }
    }

    func getDistinctAppNames() async -> [String] {
        do {
            let query = table.select(distinct: Col.appName)
                .order(Col.appName.asc)

            var appNames: [String] = []
            if let result = try db?.prepare(query) {
                for row in result {
                    if let appName = try? row.get(Col.appName), !appName.isEmpty {
                        appNames.append(appName)
                    }
                }
            }
            return appNames
        } catch {
            log.error("获取应用名称列表失败：\(error)")
            return []
        }
    }

    func getDistinctAppInfo() async -> [(name: String, path: String)] {
        do {
            var appInfo: [(name: String, path: String)] = []

            let sql = """
            SELECT app_name, app_path FROM Clip
            WHERE id IN (
                SELECT MAX(id) FROM Clip
                WHERE app_name != ''
                GROUP BY app_name
            )
            ORDER BY (
                SELECT MAX(timestamp) FROM Clip c2
                WHERE c2.app_name = Clip.app_name
            ) DESC
            """

            if let result = try db?.prepare(sql) {
                for row in result {
                    if let appName = row[0] as? String,
                       let appPath = row[1] as? String,
                       !appName.isEmpty
                    {
                        appInfo.append((name: appName, path: appPath))
                    }
                }
            }
            return appInfo
        } catch {
            log.error("获取应用信息列表失败：\(error)")
            return []
        }
    }

    func getDistinctTags() async -> [String] {
        do {
            var tags: Set<String> = []
            let query = table.select(distinct: Col.tag)
                .filter(Col.tag != nil)

            if let result = try db?.prepare(query) {
                for row in result {
                    if let tag = try? row.get(Col.tag),
                       !tag.isEmpty
                    {
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
            return try db?.scalar(query.count) ?? 0
        } catch {
            log.error("获取分组统计失败：\(error)")
            return 0
        }
    }

    func getCount(filter: Expression<Bool>?) async -> Int {
        do {
            if let filter {
                let query = table.filter(filter)
                return try db?.scalar(query.count) ?? 0
            } else {
                return try db?.scalar(table.count) ?? 0
            }
        } catch {
            log.error("获取筛选数量失败：\(error)")
            return 0
        }
    }
}

// MARK: - 数据导入导出

extension PasteSQLManager {
    struct ImportExportResult {
        let success: Bool
        let message: String
        var importedAppInfo: [(name: String, path: String)] = []
        var importedChipsData: Data?
    }

    private static let metaTable = "clip_meta"
    private static let metaChipsKey = "user_chips"

    private nonisolated static func localize(
        _ key: String,
        _ arguments: CVarArg...
    ) -> String {
        let format = Bundle.main.localizedString(
            forKey: key,
            value: key,
            table: "Localizable"
        )
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: .current, arguments: arguments)
    }

    nonisolated func exportDatabase(to destinationURL: URL, userChipsData: Data?) async -> ImportExportResult {
        let sourcePath = Self.databasePath

        return await Task.detached(priority: .userInitiated) {
            guard FileManager.default.fileExists(atPath: sourcePath) else {
                return ImportExportResult(
                    success: false,
                    message: Self.localize("noSourceDb")
                )
            }

            do {
                let sourceDb = try Connection(sourcePath)
                try sourceDb.execute("PRAGMA wal_checkpoint(TRUNCATE)")

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                try FileManager.default.copyItem(
                    atPath: sourcePath,
                    toPath: destinationURL.path
                )

                if let data = userChipsData, let json = String(data: data, encoding: .utf8) {
                    let destDb = try Connection(destinationURL.path)
                    try destDb.execute(
                        "CREATE TABLE IF NOT EXISTS \(Self.metaTable) (key TEXT PRIMARY KEY, value TEXT NOT NULL)"
                    )
                    try destDb.run(
                        "INSERT OR REPLACE INTO \(Self.metaTable) (key, value) VALUES (?, ?)",
                        [Self.metaChipsKey, json]
                    )
                }

                return ImportExportResult(
                    success: true,
                    message: Self.localize("exportSuccess")
                )
            } catch {
                return ImportExportResult(
                    success: false,
                    message: Self.localize("exportFail", error.localizedDescription)
                )
            }
        }.value
    }

    nonisolated func importDatabase(from sourceURL: URL) async -> ImportExportResult {
        let validationResult = await validateImportDatabase(at: sourceURL)
        guard validationResult.success else {
            return validationResult
        }

        let destPath = Self.databasePath

        let result = await Task.detached(priority: .userInitiated) {
            do {
                let sourceDb = try Connection(sourceURL.path, readonly: true)
                let destDb = try Connection(destPath)

                let sourceTable = Table("Clip")
                let destTable = Table("Clip")
                let rows = try sourceDb.prepare(sourceTable)

                var importedCount = 0
                var skippedCount = 0
                var appInfoDict: [String: String] = [:]

                try destDb.transaction {
                    for row in rows {
                        guard !Task.isCancelled else {
                            throw NSError(
                                domain: "ImportCancelled",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: Self.localize("importCancelled")]
                            )
                        }

                        let uniqueId = try row.get(Col.uniqueId)
                        let existingQuery = destTable.filter(Col.uniqueId == uniqueId)
                        let existingCount = try destDb.scalar(existingQuery.count)

                        if existingCount > 0 {
                            skippedCount += 1
                            continue
                        }

                        let appPath = try row.get(Col.appPath)
                        let appName = try row.get(Col.appName)

                        let insert = try destTable.insert(
                            Col.uniqueId <- uniqueId,
                            Col.type <- row.get(Col.type),
                            Col.data <- row.get(Col.data),
                            Col.showData <- row.get(Col.showData),
                            Col.ts <- row.get(Col.ts),
                            Col.appPath <- appPath,
                            Col.appName <- appName,
                            Col.searchText <- row.get(Col.searchText),
                            Col.length <- row.get(Col.length),
                            Col.group <- (try? row.get(Col.group)) ?? -1,
                            Col.tag <- try? row.get(Col.tag)
                        )

                        try destDb.run(insert)
                        importedCount += 1

                        if !appName.isEmpty, appInfoDict[appName] == nil {
                            appInfoDict[appName] = appPath
                        }
                    }
                }

                let skippedText = skippedCount > 0
                    ? Self.localize("importSkip", skippedCount)
                    : ""
                let message = Self.localize("importResult", importedCount, skippedText)

                let appInfo = appInfoDict.map { (name: $0.key, path: $0.value) }

                var chipsData: Data? = nil
                let metaExists = (try? sourceDb.scalar(
                    "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='\(Self.metaTable)'"
                ) as? Int64) ?? 0
                if metaExists > 0,
                   let rows = try? sourceDb.prepare(
                       "SELECT value FROM \(Self.metaTable) WHERE key='\(Self.metaChipsKey)'"
                   )
                {
                    for row in rows {
                        if let json = row[0] as? String {
                            chipsData = json.data(using: .utf8)
                        }
                        break
                    }
                }

                return ImportExportResult(
                    success: true,
                    message: message,
                    importedAppInfo: appInfo,
                    importedChipsData: chipsData
                )
            } catch {
                return ImportExportResult(
                    success: false,
                    message: Self.localize("importFailDetail", error.localizedDescription)
                )
            }
        }.value

        if result.success {
            await MainActor.run {
                PasteMetadataCache.shared.invalidateAllCaches()
            }
        }

        return result
    }

    private nonisolated func validateImportDatabase(at url: URL) async -> ImportExportResult {
        await Task.detached(priority: .userInitiated) {
            guard FileManager.default.fileExists(atPath: url.path) else {
                return ImportExportResult(
                    success: false,
                    message: Self.localize("noFile")
                )
            }

            do {
                let sourceDb = try Connection(url.path, readonly: true)

                let tableExists = try sourceDb.scalar(
                    "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='Clip'"
                ) as? Int64 ?? 0

                guard tableExists > 0 else {
                    return ImportExportResult(
                        success: false,
                        message: Self.localize("backupInvalid", Self.localize("missingTable"))
                    )
                }

                let requiredColumns = [
                    "unique_id", "type", "data", "timestamp",
                    "app_path", "app_name", "search_text", "length",
                ]

                let tableInfo = try sourceDb.prepare("PRAGMA table_info(Clip)")
                var existingColumns: Set<String> = []

                for row in tableInfo {
                    if let columnName = row[1] as? String {
                        existingColumns.insert(columnName)
                    }
                }

                for column in requiredColumns {
                    guard existingColumns.contains(column) else {
                        return ImportExportResult(
                            success: false,
                            message: Self.localize(
                                "backupInvalid",
                                Self.localize("missingColumn", column)
                            )
                        )
                    }
                }

                return ImportExportResult(success: true, message: Self.localize("backupValid"))
            } catch {
                return ImportExportResult(
                    success: false,
                    message: Self.localize("backupInvalid", Self.localize("backupReadFail"))
                )
            }
        }.value
    }
}

// MARK: - 数据迁移

extension PasteSQLManager {
    func migrateTagFieldAsync() {
        Task {
            let alreadyMigrated = await MainActor.run { PasteUserDefaults.tagFieldMigrated }
            guard !alreadyMigrated else {
                log.debug("Tag 数据已迁移，跳过")
                return
            }
            await performTagMigration()
            await MainActor.run {
                PasteUserDefaults.tagFieldMigrated = true
                log.info("Tag 数据迁移完成")
            }
        }
    }

    private func performTagMigration() async {
        log.info("开始迁移 tag 字段数据")

        guard let db else {
            log.error("数据库未初始化，跳过")
            return
        }

        do {
            try db.run("ALTER TABLE Clip ADD COLUMN tag TEXT")
        } catch {
            log.warn("新增 tag 字段失败: \(error)")
            return
        }

        let batchSize = 500
        var totalMigrated = 0

        while true {
            guard !Task.isCancelled else {
                log.warn("迁移任务被取消")
                break
            }

            let query = table
                .filter(Col.tag == nil)
                .limit(batchSize, offset: 0)

            do {
                let rows = try db.prepare(query)
                let rowsArray = Array(rows)

                if rowsArray.isEmpty { break }

                try db.run("BEGIN TRANSACTION")
                for row in rowsArray {
                    let id = row[Col.id]
                    let typeStr = row[Col.type]
                    let data = row[Col.data]

                    let pasteboardType = PasteboardType(typeStr)
                    let tagValue = await PasteboardModel.calculateTag(
                        type: pasteboardType,
                        content: data
                    )

                    let update = table.filter(Col.id == id)
                        .update(Col.tag <- tagValue)

                    do {
                        try db.run(update)
                    } catch {
                        log.error("更新记录 \(id) 的 tag 失败: \(error)")
                    }
                }
                try db.run("COMMIT")

                totalMigrated += rowsArray.count
                log.debug("已迁移 \(totalMigrated) 条记录")
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                log.error("迁移批次失败: \(error)")
                break
            }
        }

        log.info("tag 字段数据迁移完成，共迁移 \(totalMigrated) 条记录")
    }
}

// MARK: - 字段迁移

extension PasteSQLManager {
    func migrateHiddenFieldAsync() {
        Task {
            let alreadyMigrated = await MainActor.run { PasteUserDefaults.hiddenFieldMigrated }
            guard !alreadyMigrated else {
                log.debug("hidden 字段已增加，跳过")
                return
            }
            await performHiddenFieldMigration()
            await MainActor.run {
                PasteUserDefaults.hiddenFieldMigrated = true
                log.info("hidden 字段添加完成")
            }
        }
    }

    private func performHiddenFieldMigration() async {
        guard let db else { return }
        do {
            try db.run("ALTER TABLE Clip ADD COLUMN hidden INTEGER NOT NULL DEFAULT 0")
        } catch {
            log.warn("新增 hidden 字段失败（可能已存在）: \(error)")
        }
    }
}

// MARK: - unique_id 重算与去重迁移

extension PasteSQLManager {
    /// 历史版本 `generateUniqueId` 算法变更后，旧行存储的 `unique_id` 与运行时重算值不一致：
    /// 既会绕过插入去重产生内容相同的多行，又会让 diffable data source 因重复标识符崩溃。
    /// 本迁移用当前算法重算全表 `unique_id`，合并重复行（保留时间戳最新的），并修正存储值。
    func migrateUniqueIdAsync() {
        Task {
            let alreadyMigrated = await MainActor.run { PasteUserDefaults.uniqueIdMigrated }
            guard !alreadyMigrated else {
                log.debug("unique_id 已迁移，跳过")
                return
            }
            await performUniqueIdMigration()
            await MainActor.run {
                PasteUserDefaults.uniqueIdMigrated = true
                log.info("unique_id 迁移完成")
            }
        }
    }

    private struct UniqueIdRowInfo {
        let id: Int64
        let storedUniqueId: String
        let correctUniqueId: String
        let timestamp: Int64
        let group: Int
    }

    private func performUniqueIdMigration() async {
        guard let db else { return }
        log.info("开始重算 unique_id 并清理重复行")

        // 1. 流式读取全表，用当前算法重算 unique_id（仅保留小体积信息，及时释放 data blob）
        var infos: [UniqueIdRowInfo] = []
        do {
            let query = table.select(Col.id, Col.uniqueId, Col.type, Col.data, Col.ts, Col.group)
            for row in try db.prepare(query) {
                let type = PasteboardType(row[Col.type])
                let correct = await PasteboardModel.generateUniqueId(for: type, data: row[Col.data])
                infos.append(UniqueIdRowInfo(
                    id: row[Col.id],
                    storedUniqueId: row[Col.uniqueId],
                    correctUniqueId: correct,
                    timestamp: row[Col.ts],
                    group: row[Col.group]
                ))
            }
        } catch {
            log.error("读取数据失败，跳过 unique_id 迁移: \(error)")
            return
        }

        // 2. 按重算后的 unique_id 分组，保留时间戳最新的一行，合并分组信息
        var groups: [String: [UniqueIdRowInfo]] = [:]
        for info in infos {
            groups[info.correctUniqueId, default: []].append(info)
        }

        var idsToDelete: [Int64] = []
        var updates: [(id: Int64, uniqueId: String, group: Int?)] = []

        for (correctId, rows) in groups {
            let sorted = rows.sorted { $0.timestamp > $1.timestamp }
            let keeper = sorted[0]
            idsToDelete.append(contentsOf: sorted.dropFirst().map(\.id))

            // 分组不能丢：保留行为 -1 时继承重复行里最新的非默认分组，仅在此时才写 group
            let mergedGroup = sorted.first(where: { $0.group != -1 })?.group
            let needGroupUpdate = mergedGroup != nil && mergedGroup != keeper.group
            if keeper.storedUniqueId != correctId || needGroupUpdate {
                updates.append((keeper.id, correctId, needGroupUpdate ? mergedGroup : nil))
            }
        }

        guard !idsToDelete.isEmpty || !updates.isEmpty else {
            log.info("unique_id 无需迁移")
            return
        }

        // 3. 在事务内：先删重复行，再分两步更新（先写临时值，再写最终值），
        //    避免更新顺序与 unique_id 上的 UNIQUE 索引冲突
        do {
            try db.run("BEGIN TRANSACTION")
            for id in idsToDelete {
                try db.run(table.filter(Col.id == id).delete())
            }
            for update in updates {
                try db.run(table.filter(Col.id == update.id)
                    .update(Col.uniqueId <- "__migrating__\(update.id)"))
            }
            for update in updates {
                var setters: [Setter] = [Col.uniqueId <- update.uniqueId]
                if let group = update.group {
                    setters.append(Col.group <- group)
                }
                try db.run(table.filter(Col.id == update.id).update(setters))
            }
            try db.run("COMMIT")
            log.info("unique_id 迁移：删除重复 \(idsToDelete.count) 行，修正 \(updates.count) 行")
        } catch {
            _ = try? db.run("ROLLBACK")
            log.error("unique_id 迁移失败: \(error)")
        }
    }
}
