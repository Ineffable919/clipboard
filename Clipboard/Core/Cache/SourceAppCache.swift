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
    private var revision = 0
    private var checkedFiles: [Int64: (path: String, files: [SourceAppIcon.FileState])] = [:]

    /// 仅由复制触发，应用包文件属性未变时不再读取图标
    func refreshIconIfNeeded(for id: Int64?) {
        guard let id, let app = apps[id] else { return }
        let expected = revision
        Task(priority: .utility) { [weak self] in
            await self?.refreshIcon(for: app, revision: expected)
        }
    }

    private func refreshIcon(for app: SourceApp, revision expected: Int) async {
        guard revision == expected else { return }
        let files = await Task.detached(priority: .utility) {
            SourceAppIcon.fileState(path: app.path)
        }.value
        guard !Task.isCancelled, revision == expected, apps[app.id] == app,
              let files else { return }
        if let checked = checkedFiles[app.id], checked.path == app.path, checked.files == files { return }
        let loaded = await Task.detached(priority: .utility) {
            let icon = SourceAppIcon.read(data: nil, path: app.path)
            let color = icon.data != app.iconData
                ? icon.image.flatMap { AppIconColorExtractor.extract(from: $0) } : nil
            return (image: icon.image, data: icon.data, color: color, files: SourceAppIcon.fileState(path: app.path))
        }.value
        guard !Task.isCancelled, revision == expected, apps[app.id] == app,
              loaded.files == files, let image = loaded.image, let data = loaded.data else { return }
        if data == app.iconData {
            checkedFiles[app.id] = (app.path, files)
            return
        }
        let updated = await PasteSQLManager.manager.saveAppIcon(
            id: app.id, path: app.path, data: data, replacing: app.iconData
        )
        guard let updated,
              !Task.isCancelled, revision == expected, apps[app.id] == app else { return }
        update(updated)
        // 阻止旧的按需加载任务在刷新后把旧图重新写回缓存
        AppIconCache.shared.install(image, for: app.id)
        if let color = loaded.color {
            AppColorService.shared.refreshColor(color, name: app.name)
        }
        checkedFiles[app.id] = (app.path, files)
        changes.send()
    }

    func replace(_ records: [SourceApp]) {
        warmingTask?.cancel()
        revision &+= 1
        checkedFiles.removeAll()
        apps = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        orderedIDs = records.map(\.id)
        AppIconCache.shared.clearCache()
        changes.send()
    }

    /// SQL 写入完成后发布有历史引用的应用；不清理磁盘 App 表、不重建图标缓存
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
            // 单路补全，不阻塞首屏，不为每条历史记录创建任务
            for app in missing {
                guard !Task.isCancelled else { return }
                _ = await AppIconCache.shared.loadIcon(forAppID: app.id, path: app.path)
                await Task.yield()
            }
        }
    }
}
