//
//  AppIconCache.swift
//  Clipboard
//
//  Created by crown on 2026/3/3.
//

import AppKit

final class AppIconCache {
    static let shared = AppIconCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 50
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB
    }

    func getCachedIcon(forPath path: String) -> NSImage? {
        guard !path.isEmpty else { return nil }
        return cache.object(forKey: path as NSString)
    }

    func loadIcon(forPath path: String) async -> NSImage {
        guard !path.isEmpty else {
            return NSWorkspace.shared.icon(forFile: path)
        }

        if let cached = cache.object(forKey: path as NSString) {
            return cached
        }

        let icon = await Task.detached {
            NSWorkspace.shared.icon(forFile: path)
        }.value

        cache.setObject(icon, forKey: path as NSString)

        return icon
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    var cacheInfo: (countLimit: Int, costLimit: Int) {
        (cache.countLimit, cache.totalCostLimit)
    }
}
