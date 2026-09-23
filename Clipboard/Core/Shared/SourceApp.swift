import Foundation
import SQLite

/// 应用身份和持久化图标；历史记录只保存 id。
nonisolated struct SourceApp: Sendable, Equatable {
    let id: Int64
    let bundleID: String?
    let name: String
    let path: String
    let iconData: Data?

    static var current: SourceApp {
        let bundle = Bundle.main
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? ProcessInfo.processInfo.processName
        return SourceApp(id: 0, bundleID: bundle.bundleIdentifier, name: name,
                         path: bundle.bundlePath, iconData: nil)
    }
}

nonisolated enum SourceAppSQL {
    static func create(on database: Connection) throws {
        try database.execute("""
            CREATE TABLE IF NOT EXISTS App (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                bundle_id TEXT,
                app_name TEXT NOT NULL,
                app_path TEXT NOT NULL,
                icon_data BLOB
            );
            CREATE UNIQUE INDEX IF NOT EXISTS idx_app_bundle ON App(bundle_id) WHERE bundle_id IS NOT NULL;
            CREATE INDEX IF NOT EXISTS idx_app_path ON App(app_path, app_name);
            """)
    }

    static func readAll(on database: Connection, id: Int64? = nil, referencedOnly: Bool = false) throws -> [SourceApp] {
        let condition = id != nil ? " WHERE id = ?"
            : referencedOnly ? " WHERE EXISTS (SELECT 1 FROM Clip WHERE app_id = App.id)" : ""
        let query = "SELECT id, bundle_id, app_name, app_path, icon_data FROM App" + condition
        let bindings: [Binding?] = id.map { [$0] } ?? []
        return try database.prepare(query, bindings).map {
            SourceApp(
                id: $0[0] as? Int64 ?? 0, bundleID: $0[1] as? String,
                name: $0[2] as? String ?? "", path: $0[3] as? String ?? "",
                iconData: ($0[4] as? Blob).map { Data($0.bytes) }
            )
        }
    }

    /// 仅在身份可确认时合并；名称相同不代表同一个应用。
    static func resolve(
        name: String, path: String, bundleID: String?, iconData: Data? = nil,
        on database: Connection
    ) throws -> Int64 {
        var appID: Int64?
        if let bundleID {
            appID = try database.scalar("SELECT id FROM App WHERE bundle_id = ?", bundleID) as? Int64
        }
        if appID == nil {
            let query = path.isEmpty || bundleID == nil
                ? "SELECT id FROM App WHERE app_path = ? AND app_name = ? ORDER BY id LIMIT 1"
                : "SELECT id FROM App WHERE app_path = ? AND (bundle_id IS NULL OR bundle_id = ?) ORDER BY id LIMIT 1"
            appID = try database.scalar(query, path, path.isEmpty || bundleID == nil ? name : bundleID) as? Int64
        }
        if let appID {
            try database.run("""
                UPDATE App SET app_name = ?, app_path = ?, bundle_id = COALESCE(?, bundle_id),
                    icon_data = COALESCE(?, icon_data) WHERE id = ?
                """, name, path, bundleID, iconData.map { Blob(bytes: [UInt8]($0)) }, appID)
            return appID
        }
        try database.run("INSERT INTO App (bundle_id, app_name, app_path, icon_data) VALUES (?, ?, ?, ?)",
                         bundleID, name, path, iconData.map { Blob(bytes: [UInt8]($0)) })
        return database.lastInsertRowid
    }
    /// 仅回收无法辨识且没有持久化图标的失效来源；空路径可能是虚拟来源。
    @discardableResult
    static func reassignMissing(on database: Connection, fallback: SourceApp) throws -> Int {
        var count = 0
        try database.run("SAVEPOINT missing_source_cleanup")
        do {
            let candidates = try database.prepare("""
                SELECT id, app_path FROM App
                WHERE (bundle_id IS NULL OR bundle_id = '') AND icon_data IS NULL AND app_path != ''
                """).compactMap { row -> Int64? in
                    guard let id = row[0] as? Int64, let path = row[1] as? String,
                          !FileManager.default.fileExists(atPath: path) else { return nil }
                    return id
                }
            guard !candidates.isEmpty else {
                try database.run("RELEASE missing_source_cleanup")
                return 0
            }
            let fallbackID = try resolve(name: fallback.name, path: fallback.path,
                                         bundleID: fallback.bundleID, iconData: fallback.iconData, on: database)
            for id in candidates where id != fallbackID {
                try database.run("UPDATE Clip SET app_id = ? WHERE app_id = ?", fallbackID, id)
                try database.run("""
                    DELETE FROM App WHERE id = ? AND NOT EXISTS (SELECT 1 FROM Clip WHERE app_id = ?)
                    """, id, id)
                count += 1
            }
            try database.run("RELEASE missing_source_cleanup")
        } catch {
            try database.run("ROLLBACK TO missing_source_cleanup")
            try database.run("RELEASE missing_source_cleanup")
            throw error
        }
        return count
    }

    static func importID(for row: Row, mapping: [String: Int64], normalized: Bool) throws -> Int64 {
        let key = normalized
            ? String(try row.get(Col.appID))
            : "\(try row.get(Col.appPath))\u{0}\(try row.get(Col.appName))"
        guard let id = mapping[key] else { throw CocoaError(.fileReadCorruptFile) }
        return id
    }

    static func importIDs(
        from source: Connection, into destination: Connection, normalized: Bool
    ) throws -> [String: Int64] {
        let records: [(key: String, app: SourceApp)]
        if normalized {
            records = try SourceAppSQL.readAll(on: source).map { (String($0.id), $0) }
        } else {
            records = try source.prepare("SELECT DISTINCT app_name, app_path FROM Clip").map { row in
                let name = row[0] as? String ?? ""
                let path = row[1] as? String ?? ""
                let bundleID = path.isEmpty ? nil : Bundle(url: URL(filePath: path))?.bundleIdentifier
                return ("\(path)\u{0}\(name)", SourceApp(id: 0, bundleID: bundleID, name: name,
                                                       path: path, iconData: nil))
            }
        }
        var result: [String: Int64] = [:]
        for (key, app) in records {
            // 已有本机应用优先，导入其他机器的路径不能覆盖当前可用路径。
            let existing: Int64?
            if let bundleID = app.bundleID {
                existing = try destination.scalar("SELECT id FROM App WHERE bundle_id = ?", bundleID) as? Int64
            } else {
                existing = try destination.scalar(
                    "SELECT id FROM App WHERE app_name = ? AND app_path = ? LIMIT 1", app.name, app.path
                ) as? Int64
            }
            if let existing {
                if let data = app.iconData {
                    try destination.run("UPDATE App SET icon_data = COALESCE(icon_data, ?) WHERE id = ?",
                                        Blob(bytes: [UInt8](data)), existing)
                }
                result[key] = existing
            } else {
                result[key] = try SourceAppSQL.resolve(name: app.name, path: app.path, bundleID: app.bundleID,
                                                      iconData: app.iconData, on: destination)
            }
        }
        return result
    }

}
