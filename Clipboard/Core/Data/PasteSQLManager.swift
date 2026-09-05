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

    static var databasePath: String {
        databaseDirectory.appendingPathComponent("Clip.sqlite3").path
    }

    let connection: Connection?

    let table: Table

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
        self.connection = connection

        let tab = Table("Clip")
        table = tab

        if let conn = connection {
            try? conn.execute("PRAGMA journal_mode=WAL")
            Self.createTable(on: conn, table: tab)
        }
    }

    nonisolated static func createTable(on conn: Connection, table: Table) {
        let statement = table.create(ifNotExists: true, withoutRowid: false) { schema in
            schema.column(Col.id, primaryKey: true)
            schema.column(Col.uniqueId)
            schema.column(Col.type)
            schema.column(Col.data)
            schema.column(Col.showData)
            schema.column(Col.timestamp)
            schema.column(Col.appPath)
            schema.column(Col.appName)
            schema.column(Col.searchText)
            schema.column(Col.length)
            schema.column(Col.group, defaultValue: -1)
            schema.column(Col.tag)
            schema.column(Col.hidden, defaultValue: 0)
        }
        do {
            try conn.run(statement)
            try PasteOrder.setup(on: conn)
        } catch {
            log.error("Create Table Error: \(error)")
        }
    }

    nonisolated static func createIndexes(on conn: Connection) {
        let indexes = [
            (
                "idx_app_hidden_ts",
                "CREATE INDEX IF NOT EXISTS idx_app_hidden_ts ON Clip(app_name, hidden, timestamp DESC)"
            ),
            (
                "idx_tag_hidden_ts",
                "CREATE INDEX IF NOT EXISTS idx_tag_hidden_ts ON Clip(tag, hidden, timestamp DESC)"
            ),
            (
                "idx_group_ts",
                "CREATE INDEX IF NOT EXISTS idx_group_ts ON Clip(\"group\", timestamp DESC)"
            ),
            (
                "uidx_unique_id",
                "CREATE UNIQUE INDEX IF NOT EXISTS uidx_unique_id ON Clip(unique_id)"
            ),
            (
                "idx_hidden_ts",
                "CREATE INDEX IF NOT EXISTS idx_hidden_ts ON Clip(hidden, timestamp DESC)"
            )
        ]

        var failedIndexes: [String] = []
        for (name, statement) in indexes {
            do {
                try conn.run(statement)
            } catch {
                failedIndexes.append(name)
                log.warn("创建索引 \(name) 失败: \(error)")
            }
        }

        guard failedIndexes.isEmpty else { return }

        let obsoleteIndexes = [
            "idx_app_name",
            "idx_tag",
            "idx_ts",
            "idx_group",
            "idx_unique_id"
        ]
        for name in obsoleteIndexes {
            do {
                try conn.run("DROP INDEX IF EXISTS \(name)")
            } catch {
                log.warn("清理旧索引 \(name) 失败: \(error)")
            }
        }
        log.info("索引初始化成功")
    }

    func setup() async {
        await migrateUniqueIdIfNeeded()

        guard let connection else { return }
        Self.createIndexes(on: connection)
    }
}
