import AppKit

@MainActor
final class AppIconCache {
    static let shared = AppIconCache()
    private let cache = NSCache<NSString, NSImage>()
    private var inFlightTasks: [String: Task<NSImage, Never>] = [:]
    private var generation = 0
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
        if let task = inFlightTasks[key] { return await task.value }
        let app = id.flatMap { SourceAppCache.shared.apps[$0] }
        let iconData = app?.iconData
        let sourcePath = app?.path ?? path
        let currentGeneration = generation
        let task = Task { [fallback] in
            let loaded = await Task.detached(priority: .utility) {
                SourceAppIcon.read(data: iconData, path: sourcePath)
            }.value
            guard self.generation == currentGeneration else { return fallback }
            if let data = loaded.data, let id {
                Task(priority: .utility) { [self] in
                    let updated = await PasteSQLManager.manager.saveAppIcon(id: id, path: sourcePath, data: data)
                    guard generation == currentGeneration, let updated else { return }
                    SourceAppCache.shared.update(updated)
                }
            }
            return loaded.image ?? fallback
        }
        inFlightTasks[key] = task
        let image = await task.value
        if generation == currentGeneration {
            cache.setObject(image, forKey: key as NSString, cost: SourceAppIcon.cacheCost)
            inFlightTasks[key] = nil
        }
        return image
    }

    func clearCache() {
        generation &+= 1
        inFlightTasks.values.forEach { $0.cancel() }
        inFlightTasks.removeAll()
        cache.removeAllObjects()
    }

    private func key(id: Int64?, path: String) -> String {
        id.map { "app:\($0)" } ?? "path:\(path)"
    }

}
