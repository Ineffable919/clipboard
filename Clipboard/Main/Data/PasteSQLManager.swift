//
//  PasteSQLManager.swift
//  Clipboard
//
//  Created by crown on 2025/9/16.
//

import AppKit
import Foundation
import SQLite

enum Col {
    static let id = Expression<Int64>("id")
    static let uniqueId = Expression<String>("unique_id")
    static let type = Expression<String>("type")
    static let data = Expression<Data>("data")
    static let showData = Expression<Data?>("show_data")
    static let ts = Expression<Int64>("timestamp")
    static let appPath = Expression<String>("app_path")
    static let appName = Expression<String>("app_name")
    static let searchText = Expression<String>("search_text")
    static let length = Expression<Int>("length")
    static let group = Expression<Int>("group")
    static let tag = Expression<String?>("tag")
}

final class PasteSQLManager: NSObject {
    static let manager = PasteSQLManager()
    private static var isInitialized = false
    private nonisolated static let initLock = NSLock()

    private static var legacyDatabasePath: String {
        let home = NSHomeDirectory()
        if home.contains("/Library/Containers/") {
            let components = home.components(separatedBy: "/Library/Containers/")
            if let userHome = components.first {
                return "\(userHome)/Documents/Clip/Clip.sqlite3"
            }
        }
        return "\(home)/Documents/Clip/Clip.sqlite3"
    }

    private static var sandboxDatabaseDirectory: String {
        URL.documentsDirectory.appending(path: "Clip").path
    }

    private static var sandboxDatabasePath: String {
        "\(sandboxDatabaseDirectory)/Clip.sqlite3"
    }

    private lazy var db: Connection? = {
        Self.initLock.lock()
        defer { Self.initLock.unlock() }

        if Self.isInitialized {
            return nil
        }

        let path = Self.sandboxDatabaseDirectory
        var isDir = ObjCBool(false)
        let filExist = FileManager.default.fileExists(
            atPath: path,
            isDirectory: &isDir,
        )
        if !filExist || !isDir.boolValue {
            do {
                try FileManager.default.createDirectory(
                    atPath: path,
                    withIntermediateDirectories: true,
                )
            } catch {
                log.debug(error.localizedDescription)
            }
        }
        do {
            let db = try Connection("\(path)/Clip.sqlite3")
            log.debug("数据库初始化 - 路径：\(path)/Clip.sqlite3")
            db.busyTimeout = 5.0
            Self.isInitialized = true
            return db
        } catch {
            log.error("Connection Error\(error)")
        }
        return nil
    }()

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
            try db?.run(stateMent)
            createIndexesAsync()
            migrateTagFieldAsync()
        } catch {
            log.error("Create Table Error: \(error)")
        }
        return tab
    }()

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
            log.info("索引初始化成功")
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
            Col.tag <- item.tag,
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
            Col.tag <- item.tag,
        )
        do {
            let count = try db?.run(update)
            log.debug("修改成功，影响行数：\(String(describing: count))")
        } catch {
            log.error("修改失败：\(error)")
        }
    }

    // 更新项目分组
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

    // 查
    func search(
        filter: Expression<Bool>? = nil,
        select: [Expressible]? = nil,
        order: [Expressible]? = nil,
        limit: Int? = nil,
        offset: Int? = nil,
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
}

// MARK: - 数据迁移

extension PasteSQLManager {
    private static let sandboxMigrationKey = "sandboxDataMigrated"

    private static var hasMigratedToSandbox: Bool {
        get { UserDefaults.standard.bool(forKey: sandboxMigrationKey) }
        set { UserDefaults.standard.set(newValue, forKey: sandboxMigrationKey) }
    }

    private static var legacyUserDefaultsPath: String {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.crown.clipboard"
        let home = NSHomeDirectory()
        if home.contains("/Library/Containers/") {
            let components = home.components(separatedBy: "/Library/Containers/")
            if let userHome = components.first {
                return "\(userHome)/Library/Preferences/\(bundleId).plist"
            }
        }
        return "\(home)/Library/Preferences/\(bundleId).plist"
    }

    private static var needsSandboxMigration: Bool {
        guard !hasMigratedToSandbox else { return false }
        return FileManager.default.fileExists(atPath: legacyDatabasePath)
    }

    static func performSandboxMigrationIfNeeded() {
        guard needsSandboxMigration else {
            if hasMigratedToSandbox {
                log.info("沙盒迁移：已完成迁移，跳过")
            } else {
                log.info("沙盒迁移：无旧数据需要迁移")
                hasMigratedToSandbox = true
            }
            return
        }

        log.info("开始沙盒数据迁移...")

        let fileManager = FileManager.default
        let legacyDir = (legacyDatabasePath as NSString).deletingLastPathComponent

        var migrationSuccess = true

        do {
            try fileManager.createDirectory(
                atPath: sandboxDatabaseDirectory,
                withIntermediateDirectories: true
            )

            let filesToMigrate = ["Clip.sqlite3", "Clip.sqlite3-shm", "Clip.sqlite3-wal"]

            for fileName in filesToMigrate {
                let sourcePath = "\(legacyDir)/\(fileName)"
                let destPath = "\(sandboxDatabaseDirectory)/\(fileName)"

                guard fileManager.fileExists(atPath: sourcePath) else { continue }

                try? fileManager.removeItem(atPath: destPath)
                try fileManager.copyItem(atPath: sourcePath, toPath: destPath)
                log.info("已迁移数据库文件: \(fileName)")
            }
        } catch {
            log.error("数据库迁移失败: \(error)")
            migrationSuccess = false
        }

        migrateUserDefaults()

        if migrationSuccess {
            hasMigratedToSandbox = true
            log.info("沙盒数据迁移完成")
        }
    }

    private static func migrateUserDefaults() {
        guard FileManager.default.fileExists(atPath: legacyUserDefaultsPath) else {
            log.warn("\(legacyUserDefaultsPath) UserDefaults文件不存在")
            return
        }

        guard let legacyDefaults = NSDictionary(contentsOfFile: legacyUserDefaultsPath) as? [String: Any] else {
            log.warn("读取\(legacyUserDefaultsPath) UserDefaults文件失败")
            return
        }

        let appDefinedKeys: Set<String> = Set(PrefKey.allCases.map(\.rawValue))

        let currentDefaults = UserDefaults.standard
        var migratedCount = 0

        for (key, value) in legacyDefaults {
            if key.hasPrefix("NS") || key.hasPrefix("Apple") {
                continue
            }

            if appDefinedKeys.contains(key) {
                currentDefaults.set(value, forKey: key)
                log.debug("迁移 UserDefaults: \(key), 类型: \(type(of: value))")
                migratedCount += 1
            }
        }

        currentDefaults.synchronize()
        log.info("已迁移 \(migratedCount) 个 UserDefaults 键值")
    }

    /// 清理数据
    static func cleanupLegacyData() {
        let fileManager = FileManager.default
        let legacyDir = (legacyDatabasePath as NSString).deletingLastPathComponent

        do {
            if fileManager.fileExists(atPath: legacyDir) {
                try fileManager.removeItem(atPath: legacyDir)
                log.info("已清理旧数据目录\(legacyDir)")
            }
        } catch {
            log.warn("清理旧数据目录\(legacyDir)，失败: \(error)")
        }

        do {
            if fileManager.fileExists(atPath: legacyUserDefaultsPath) {
                try fileManager.removeItem(atPath: legacyUserDefaultsPath)
                log.info("已清理旧 UserDefaults 文件\(legacyUserDefaultsPath)")
            }
        } catch {
            log.warn("清理旧 UserDefaults 文件\(legacyUserDefaultsPath)，失败: \(error)")
        }
    }

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
                                content: data,
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
