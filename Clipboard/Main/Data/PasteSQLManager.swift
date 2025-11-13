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
            true
        ).first!.appending("/Clip")
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
            let db = try Connection("\(path)/Clip.sqlite3")
            log.debug("数据库初始化 - 路径：\(path)/Clip.sqlite3")
            db.busyTimeout = 5.0
            Self.isInitialized = true
            return db
        } catch {
            log.debug("Connection Error\(error)")
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
        }
        do {
            try db?.run(stateMent)
        } catch {
            log.debug("Create Table Error: \(error)")
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
            log.debug("获取总数失败：\(error)")
            return 0
        }
    }

    // 增
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
            Col.group <- item.group
        )
        do {
            let rowId = try db?.run(insert)
            log.debug("插入成功：\(String(describing: rowId))")
            return rowId!
        } catch {
            log.debug("插入失败：\(error)")
        }
        return -1
    }

    // 根据条件删除
    func delete(filter: Expression<Bool>) async {
        let query = table.filter(filter)
        do {
            let count = try db?.run(query.delete())
            log.debug("删除的条数为：\(String(describing: count))")
        } catch {
            log.debug("删除失败：\(error)")
        }
    }

    func dropTable() {
        do {
            let d = try db?.run(table.drop())
            log.debug("删除所有\(String(describing: d?.columnCount))")
        } catch {
            log.debug("删除失败：\(error)")
        }
    }

    // 改
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
            Col.group <- item.group
        )
        do {
            let count = try db?.run(update)
            log.debug("修改成功，影响行数：\(String(describing: count))")
        } catch {
            log.debug("修改失败：\(error)")
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
            log.debug("更新项目分组失败：\(error)")
        }
    }

    // 查
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
            log.debug("查询失败：\(error)")
            return []
        }
    }
}
