import Combine
import Foundation

@MainActor
final class SourceAppCache {
    static let shared = SourceAppCache()
    private(set) var apps: [Int64: SourceApp] = [:]
    private var orderedIDs: [Int64] = []
    let changes = PassthroughSubject<Void, Never>()

    var orderedApps: [SourceApp] {
        orderedIDs.compactMap { apps[$0] }.filter { !$0.name.isEmpty }
    }
    private var warmingTask: Task<Void, Never>?

    func replace(_ records: [SourceApp]) {
        warmingTask?.cancel()
        apps = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        orderedIDs = records.map(\.id)
        AppIconCache.shared.clearCache()
        changes.send()
    }

    /// SQL 写入完成后发布有历史引用的应用；不清理磁盘 App 表、不重建图标缓存。
    func synchronize(_ records: [SourceApp]) {
        let ids = records.map(\.id)
        let updated = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        guard orderedIDs != ids || apps != updated else { return }
        if records.contains(where: { app in
            apps[app.id].map { $0.path != app.path } ?? false
        }) {
            AppIconCache.shared.clearCache()
        }
        orderedIDs = ids
        apps = updated
        changes.send()
    }

    func update(_ app: SourceApp) {
        guard apps[app.id] != app else { return }
        if let previous = apps[app.id], previous.path != app.path { AppIconCache.shared.clearCache() }
        guard apps[app.id] != nil else { return }
        apps[app.id] = app
    }

    func warmMissingIcons() {
        warmingTask?.cancel()
        let missing = apps.values.filter { $0.iconData == nil && !$0.path.isEmpty }
        warmingTask = Task(priority: .utility) {
            // 单路补全，不阻塞首屏，不为每条历史记录创建任务。
            for app in missing {
                guard !Task.isCancelled else { return }
                _ = await AppIconCache.shared.loadIcon(forAppID: app.id, path: app.path)
                await Task.yield()
            }
        }
    }
}
