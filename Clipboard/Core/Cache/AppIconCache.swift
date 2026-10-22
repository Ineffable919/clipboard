import AppKit
import Combine

@MainActor
final class AppIconCache {
    static let shared = AppIconCache()
    private let cache = NSCache<NSString, NSImage>()
    private var inFlightTasks: [String: Task<NSImage, Never>] = [:]
    private var generation = 0
    private var revisions: [String: Int] = [:]
    let changes = PassthroughSubject<Int64, Never>()

    func install(_ image: NSImage, for id: Int64) {
        let key = key(id: id, path: "")
        revisions[key, default: 0] += 1
        inFlightTasks.removeValue(forKey: key)?.cancel()
        cache.setObject(image, forKey: key as NSString, cost: SourceAppIcon.cacheCost)
        changes.send(id)
    }

    private let fallback = NSImage(
        systemSymbolName: "questionmark.app.dashed", accessibilityDescription: nil
    ) ?? NSImage()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 10 * 1024 * 1024
    }

    func getCachedIcon(forAppID id: Int64?, path: String = "") -> NSImage? {
        cache.object(forKey: key(id: id, path: path) as NSString)
    }

    func loadIcon(forAppID id: Int64?, path: String = "") async -> NSImage {
        let key = key(id: id, path: path)
        if let image = cache.object(forKey: key as NSString) { return image }
        if let task = inFlightTasks[key] {
            let image = await task.value
            return cache.object(forKey: key as NSString) ?? image
        }
        let app = id.flatMap { SourceAppCache.shared.apps[$0] }
        let iconData = app?.iconData
        let sourcePath = app?.path ?? path
        let currentGeneration = generation
        let revision = revisions[key, default: 0]
        let task = Task { [fallback] in
            let loaded = await Task.detached(priority: .utility) {
                SourceAppIcon.read(data: iconData, path: sourcePath)
            }.value
            guard self.generation == currentGeneration,
                  self.revisions[key, default: 0] == revision else {
                return self.cache.object(forKey: key as NSString) ?? fallback
            }
            if let data = loaded.data, let id {
                Task(priority: .utility) { [self] in
                    guard generation == currentGeneration, revisions[key, default: 0] == revision else { return }
                    let updated = await PasteSQLManager.manager.saveAppIcon(
                        id: id, path: sourcePath, data: data, replacing: iconData
                    )
                    guard generation == currentGeneration,
                          revisions[key, default: 0] == revision, let updated else { return }
                    SourceAppCache.shared.update(updated)
                }
            }
            return loaded.image ?? fallback
        }
        inFlightTasks[key] = task
        let image = await task.value
        if generation == currentGeneration, revisions[key, default: 0] == revision {
            cache.setObject(image, forKey: key as NSString, cost: SourceAppIcon.cacheCost)
            inFlightTasks[key] = nil
        }
        return cache.object(forKey: key as NSString) ?? image
    }

    func clearCache() {
        generation &+= 1
        inFlightTasks.values.forEach { $0.cancel() }
        inFlightTasks.removeAll()
        revisions.removeAll()
        cache.removeAllObjects()
    }

    private func key(id: Int64?, path: String) -> String {
        id.map { "app:\($0)" } ?? "path:\(path)"
    }

}
