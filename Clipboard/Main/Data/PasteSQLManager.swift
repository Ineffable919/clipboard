//
//  PasteSQLManager.swift
//  Clipboard
//
//  Created by crown on 2025/9/16.
//

import AppKit
import Foundation
import SQLite

struct Col: Sendable {
    nonisolated static let id = Expression<Int64>("id")
    nonisolated static let uniqueId = Expression<String>("unique_id")
    nonisolated static let type = Expression<String>("type")
    nonisolated static let data = Expression<Data>("data")
    nonisolated static let showData = Expression<Data?>("show_data")
    nonisolated static let ts = Expression<Int64>("timestamp")
    nonisolated static let appPath = Expression<String>("app_path")
    nonisolated static let appName = Expression<String>("app_name")
    nonisolated static let searchText = Expression<String>("search_text")
    nonisolated static let length = Expression<Int>("length")
    nonisolated static let group = Expression<Int>("group")
    nonisolated static let tag = Expression<String?>("tag")

    private init() {}
}

final class PasteSQLManager: NSObject, @unchecked Sendable {
    static let manager = PasteSQLManager()
    private static var isInitialized = false
    private nonisolated static let initLock = NSLock()

    private static var sandboxDatabaseDirectory: String {
        URL.documentsDirectory.appending(path: "Clip").path
    }

    private static var sandboxDatabasePath: String {
        "\(sandboxDatabaseDirectory)/Clip.sqlite3"
    }

    private let dbLock = NSLock()
    private var _db: Connection?

    private var db: Connection? {
        dbLock.withLock { _db }
    }

    private lazy var table: Table = {
        let tab = Table("Clip")
        let stateMent = tab.create(ifNotExists: true, withoutRowid: false) {
            t in
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
        }
        do {
            _ = try dbLock.withLock {
                try _db?.run(stateMent)
            }
            createIndexesAsync()
            migrateTagFieldAsync()
        } catch {
            log.error("Create Table Error: \(error)")
        }
        return tab
    }()

    override private init() {
        super.init()
        Self.initLock.lock()
        defer { Self.initLock.unlock() }

        if Self.isInitialized {
            return
        }

        let path = Self.sandboxDatabaseDirectory
        var isDir = ObjCBool(false)
        let filExist = FileManager.default.fileExists(
            atPath: path,
            isDirectory: &isDir
        )
        if !filExist || !isDir.boolValue {
            do {
                try FileManager.default.createDirectory(
                    atPath: path,
                    withIntermediateDirectories: true
                )
            } catch {
                log.debug(error.localizedDescription)
            }
        }
        do {
            let connection = try Connection("\(path)/Clip.sqlite3")
            log.info("数据库初始化 - 路径：\(path)/Clip.sqlite3")
            connection.busyTimeout = 5.0
            dbLock.withLock {
                _db = connection
            }
            Self.isInitialized = true
        } catch {
            log.error("Connection Error\(error)")
        }
    }

    private func createIndexesAsync() {
        Task.detached(priority: .background) { [weak self] in
            await self?.performIndexCreation()
        }
    }

    private func performIndexCreation() {
        guard let db else { return }

        do {
            try db.run("CREATE INDEX IF NOT EXISTS idx_app_name ON Clip(app_name)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_tag ON Clip(tag)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_ts ON Clip(timestamp DESC)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_group ON Clip(\"group\")")
            log.debug("索引初始化成功")
        } catch {
            log.debug("索引已存在或创建失败: \(error)")
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

    func insert(item: PasteboardModel) async -> Int64 {
        let query = table
        await delete(filter: Col.uniqueId == item.uniqueId)
        let insert = query.insert(
            Col.uniqueId <- item.uniqueId,
            Col.type <- item.pasteboardType.rawValue,
            Col.data <- item.data,
            Col.showData <- item.showData,
            Col.ts <- item.timestamp,
            Col.appPath <- item.appPath,
            Col.appName <- item.appName,
            Col.searchText <- item.searchText,
            Col.length <- item.length,
            Col.group <- item.group,
            Col.tag <- item.tag
        )
        do {
            let rowId = try db?.run(insert)
            log.debug("插入成功：\(String(describing: rowId))")
            return rowId!
        } catch {
            log.error("插入失败：\(error)")
        }
        return -1
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

    func dropTable() async {
        do {
            let d = try db?.run(table.drop())
            log.debug("删除所有\(String(describing: d?.columnCount))")
        } catch {
            log.error("删除失败：\(error)")
        }
    }

    func update(id: Int64, item: PasteboardModel) async {
        let query = table.filter(Col.id == id)
        let update = query.update(
            Col.type <- item.pasteboardType.rawValue,
            Col.data <- item.data,
            Col.showData <- item.showData,
            Col.ts <- item.timestamp,
            Col.appPath <- item.appPath,
            Col.appName <- item.appName,
            Col.searchText <- item.searchText,
            Col.length <- item.length,
            Col.group <- item.group,
            Col.tag <- item.tag
        )
        do {
            let count = try db?.run(update)
            log.debug("修改成功，影响行数：\(String(describing: count))")
        } catch {
            log.error("修改失败：\(error)")
        }
    }

    /// 更新项目分组
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

    /// 编辑更新
    func updateItemContent(
        id: Int64,
        data: Data,
        showData: Data?,
        searchText: String,
        length: Int,
        tag: String
    ) async {
        let query = table.filter(Col.id == id)
        let timestamp = Int64(Date().timeIntervalSince1970)
        let update = query.update(
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

    /// 查
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
                Col.tag,
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
    struct ImportExportResult: Sendable {
        let success: Bool
        let message: String
    }

    /// 导出数据库到指定路径
    nonisolated func exportDatabase(to destinationURL: URL) async -> ImportExportResult {
        let sourcePath = await Self.sandboxDatabasePath

        return await Task.detached(priority: .userInitiated) {
            guard FileManager.default.fileExists(atPath: sourcePath) else {
                return ImportExportResult(success: false, message: "源数据库文件不存在")
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

                return ImportExportResult(success: true, message: "导出成功")
            } catch {
                return ImportExportResult(
                    success: false,
                    message: "导出失败：\(error.localizedDescription)"
                )
            }
        }.value
    }

    /// 从指定路径导入数据库
    nonisolated func importDatabase(from sourceURL: URL) async -> ImportExportResult {
        let validationResult = await validateImportDatabase(at: sourceURL)
        guard validationResult.success else {
            return validationResult
        }

        let destPath = await Self.sandboxDatabasePath

        return await Task.detached(priority: .userInitiated) {
            do {
                let sourceDb = try Connection(sourceURL.path, readonly: true)
                let destDb = try Connection(destPath)

                let sourceTable = Table("Clip")
                let destTable = Table("Clip")
                let rows = try sourceDb.prepare(sourceTable)

                var importedCount = 0
                var skippedCount = 0

                try destDb.transaction {
                    for row in rows {
                        guard !Task.isCancelled else {
                            throw NSError(
                                domain: "ImportCancelled",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "导入被取消"]
                            )
                        }

                        let uniqueId = try row.get(Col.uniqueId)

                        // uniqueId 去重
                        let existingQuery = destTable.filter(Col.uniqueId == uniqueId)
                        let existingCount = try destDb.scalar(existingQuery.count)

                        if existingCount > 0 {
                            skippedCount += 1
                            continue
                        }

                        let insert = try destTable.insert(
                            Col.uniqueId <- uniqueId,
                            Col.type <- row.get(Col.type),
                            Col.data <- row.get(Col.data),
                            Col.showData <- row.get(Col.showData),
                            Col.ts <- row.get(Col.ts),
                            Col.appPath <- row.get(Col.appPath),
                            Col.appName <- row.get(Col.appName),
                            Col.searchText <- row.get(Col.searchText),
                            Col.length <- row.get(Col.length),
                            Col.group <- (try? row.get(Col.group)) ?? -1,
                            Col.tag <- try? row.get(Col.tag)
                        )

                        try destDb.run(insert)
                        importedCount += 1
                    }
                }

                let message = "成功导入 \(importedCount) 条记录" +
                    (skippedCount > 0 ? "，跳过 \(skippedCount) 条重复记录" : "")

                return ImportExportResult(success: true, message: message)
            } catch {
                return ImportExportResult(
                    success: false,
                    message: "导入失败：\(error.localizedDescription)"
                )
            }
        }.value
    }

    /// 验证导入的数据库文件格式
    private nonisolated func validateImportDatabase(at url: URL) async -> ImportExportResult {
        await Task.detached(priority: .userInitiated) {
            guard FileManager.default.fileExists(atPath: url.path) else {
                return ImportExportResult(success: false, message: "文件不存在")
            }

            do {
                let sourceDb = try Connection(url.path, readonly: true)

                let tableExists = try sourceDb.scalar(
                    "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='Clip'"
                ) as? Int64 ?? 0

                guard tableExists > 0 else {
                    return ImportExportResult(
                        success: false,
                        message: "无效的备份文件：缺少 Clip 表"
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
                            message: "无效的备份文件：缺少必要的列 \(column)"
                        )
                    }
                }

                let sampleQuery = "SELECT unique_id, type, data, timestamp FROM Clip LIMIT 1"
                if let row = try sourceDb.prepare(sampleQuery).makeIterator().next() {
                    guard row[0] is String else {
                        return ImportExportResult(
                            success: false,
                            message: "无效的备份文件：unique_id 字段类型错误"
                        )
                    }

                    guard row[1] is String else {
                        return ImportExportResult(
                            success: false,
                            message: "无效的备份文件：type 字段类型错误"
                        )
                    }

                    guard row[2] is SQLite.Blob else {
                        return ImportExportResult(
                            success: false,
                            message: "无效的备份文件：data 字段类型错误"
                        )
                    }

                    guard row[3] is Int64 else {
                        return ImportExportResult(
                            success: false,
                            message: "无效的备份文件：timestamp 字段类型错误"
                        )
                    }
                }

                return ImportExportResult(success: true, message: "验证通过")
            } catch {
                return ImportExportResult(
                    success: false,
                    message: "无效的备份文件：无法读取数据库"
                )
            }
        }.value
    }
}

// MARK: - 数据迁移

extension PasteSQLManager {
    func migrateTagFieldAsync() {
        guard !PasteUserDefaults.tagFieldMigrated else {
            log.debug("数据已迁移，跳过")
            return
        }

        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }

            await performTagMigration()

            await MainActor.run {
                PasteUserDefaults.tagFieldMigrated = true
                log.info("数据迁移完成")
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

                if rowsArray.isEmpty {
                    break
                }

                try db.transaction {
                    for row in rowsArray {
                        autoreleasepool {
                            let id = row[Col.id]
                            let typeStr = row[Col.type]
                            let data = row[Col.data]

                            let pasteboardType = PasteboardType(typeStr)
                            let tagValue = PasteboardModel.calculateTag(
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
                    }
                }

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
