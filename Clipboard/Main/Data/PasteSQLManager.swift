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

    private lazy var db: Connection? = {
        Self.initLock.lock()
        defer { Self.initLock.unlock() }

        if Self.isInitialized {
            return nil
        }

        let path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory,
            .userDomainMask,
            true,
        ).first!.appending("/Clip")
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
            migrateTagFieldAsync()
        } catch {
            log.error("Create Table Error: \(error)")
        }
        return tab
    }()
}

// MARK: - 数据库操作 对外接口

extension PasteSQLManager {
    var totalCount: Int {
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

    func dropTable() {
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

    // 获取所有唯一的应用名称
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

    // 获取应用名称和对应的路径（每个应用名称取第一个路径）
    func getDistinctAppInfo() async -> [(name: String, path: String)] {
        do {
            var appInfo: [(name: String, path: String)] = []
            var seenNames: Set<String> = []

            let query = table.select(Col.appName, Col.appPath)
                .order(Col.appName.asc, Col.ts.desc)

            if let result = try db?.prepare(query) {
                for row in result {
                    if let appName = try? row.get(Col.appName),
                       let appPath = try? row.get(Col.appPath),
                       !appName.isEmpty,
                       !seenNames.contains(appName)
                    {
                        appInfo.append((name: appName, path: appPath))
                        seenNames.insert(appName)
                    }
                }
            }
            return appInfo
        } catch {
            log.error("获取应用信息列表失败：\(error)")
            return []
        }
    }

    // 获取数据库中存在的不同 tag 类型
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
            log.debug("添加 tag 列失败: \(error)")
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

                try await Task.sleep(for: .milliseconds(100))

            } catch {
                log.error("迁移批次失败: \(error)")
                break
            }
        }

        log.info("tag 字段数据迁移完成，共迁移 \(totalMigrated) 条记录")
    }
}
