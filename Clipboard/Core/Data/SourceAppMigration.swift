import Foundation
import SQLite

nonisolated enum SourceAppMigration {
    /// 首次升级仅按不同来源读取应用身份；不读取图标，不把历史内容加载到 Swift 内存。
    @discardableResult
    static func run(on database: Connection, backupURL: URL) throws -> Bool {
        let columns = try database.prepare("PRAGMA table_info(Clip)").compactMap { $0[1] as? String }
        guard columns.contains("app_name") else { return false }
        let backup = try database.backup(usingConnection: Connection(backupURL.path))
        try backup.step()

        let hadUniqueIndex = (try database.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name='uidx_unique_id'"
        ) as? Int64 ?? 0) > 0
        try database.transaction(.immediate) {
            try database.run("""
                CREATE TEMP TABLE AppMigration (
                    app_name TEXT NOT NULL, app_path TEXT NOT NULL, app_id INTEGER NOT NULL,
                    PRIMARY KEY (app_name, app_path)
                ) WITHOUT ROWID
                """)
            try mapSources(on: database)
            // 一次顺序复制同时移除两个旧字段；ID、内容、分类、隐藏状态和排序原样保留。
            try database.execute("""
                CREATE TABLE Clip_app_migration (
                    id INTEGER PRIMARY KEY, unique_id TEXT NOT NULL, type TEXT NOT NULL,
                    data BLOB NOT NULL, show_data BLOB, timestamp INTEGER NOT NULL,
                    app_id INTEGER NOT NULL, search_text TEXT NOT NULL, length INTEGER NOT NULL,
                    "group" INTEGER NOT NULL DEFAULT -1, tag TEXT, hidden INTEGER NOT NULL DEFAULT 0,
                    sort_order INTEGER NOT NULL DEFAULT 0
                );
                INSERT INTO Clip_app_migration
                SELECT c.id, c.unique_id, c.type, c.data, c.show_data, c.timestamp,
                    a.app_id, c.search_text, c.length, c."group", c.tag, c.hidden, c.sort_order
                FROM Clip c JOIN AppMigration a ON c.app_name = a.app_name AND c.app_path = a.app_path;
                """)
            let originalCount = try database.scalar("SELECT COUNT(*) FROM Clip") as? Int64
            let migratedCount = try database.scalar("SELECT COUNT(*) FROM Clip_app_migration") as? Int64
            guard originalCount == migratedCount else { throw CocoaError(.fileReadCorruptFile) }
            try database.execute("""
                DROP TABLE Clip;
                ALTER TABLE Clip_app_migration RENAME TO Clip;
                DROP TABLE AppMigration;
                """)
            try database.run("CREATE INDEX idx_app_hidden_ts ON Clip(app_id, hidden, timestamp DESC)")
            if hadUniqueIndex {
                try database.run("CREATE UNIQUE INDEX IF NOT EXISTS uidx_unique_id ON Clip(unique_id)")
            }
        }
        try PasteOrder.setup(on: database)
        return true
    }

    private static func mapSources(on database: Connection) throws {
        let sources = try database.prepare("""
            SELECT app_name, app_path, MAX(timestamp) AS latest FROM Clip
            GROUP BY app_name, app_path ORDER BY latest
            """)
        for row in sources {
            let name = row[0] as? String ?? ""
            let path = row[1] as? String ?? ""
            let bundleID = path.isEmpty ? nil : Bundle(url: URL(filePath: path))?.bundleIdentifier
            let id = try SourceAppSQL.resolve(name: name, path: path, bundleID: bundleID, on: database)
            try database.run("INSERT INTO AppMigration VALUES (?, ?, ?)", name, path, id)
    }
    }
}
