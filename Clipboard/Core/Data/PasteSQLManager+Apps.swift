import Foundation
import SQLite

extension PasteSQLManager {
    func loadApps() throws {
        guard let connection else { return }
        let records = try SourceAppSQL.readAll(on: connection, referencedOnly: true)
        apps = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        appIdentities.removeAll()
    }

    func sourceApps(ids: Set<Int64>) throws -> [SourceApp] {
        if ids.contains(where: { apps[$0] == nil }) { try loadApps() }
        return ids.compactMap { apps[$0] }
    }

    func refreshAppCache() async {
        let records = getDistinctAppInfo()
        await MainActor.run { SourceAppCache.shared.synchronize(records) }
    }

    func resolveApp(name: String, path: String, bundleID: String?) throws -> Int64 {
        let key = "\(bundleID ?? "")\u{0}\(path)\u{0}\(name)"
        if let id = appIdentities[key], let app = apps[id], app.name == name, app.path == path {
            return id
        }
        guard let connection else { throw CocoaError(.fileReadUnknown) }
        let id = try SourceAppSQL.resolve(name: name, path: path, bundleID: bundleID, on: connection)
        let previous = try apps[id] ?? SourceAppSQL.readAll(on: connection, id: id).first
        apps[id] = SourceApp(id: id, bundleID: bundleID ?? previous?.bundleID,
                             name: name, path: path, iconData: previous?.iconData)
        appIdentities[key] = id
        return id
    }

    func saveAppIcon(id: Int64, path: String, data: Data) -> SourceApp? {
        guard let connection, let app = apps[id], app.path == path else { return nil }
        do {
            try connection.run("UPDATE App SET icon_data = ? WHERE id = ?", Blob(bytes: [UInt8](data)), id)
            let updated = SourceApp(id: id, bundleID: app.bundleID, name: app.name, path: path, iconData: data)
            apps[id] = updated
            return updated
        } catch {
            log.error("保存应用图标失败：\(error)")
            return nil
        }
    }

}
