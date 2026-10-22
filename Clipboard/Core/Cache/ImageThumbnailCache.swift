//
//  ImageThumbnailCache.swift
//  Clipboard
//
//  Created by crown on 2026/10/22.
//

import Foundation
import ImageIO

/// 串行解码，缓存只保留降采样像素；离屏模型不持有图片
actor ImageThumbnailCache {
    static let shared = ImageThumbnailCache()

    private struct Entry {
        let image: CGImage
        let cost: Int
        var access: UInt64
    }

    private let costLimit: Int
    private var entries: [String: Entry] = [:]
    private(set) var totalCost = 0
    private var access: UInt64 = 0

    init(costLimit: Int = 32 * 1024 * 1024) {
        self.costLimit = costLimit
    }

    func image(for id: String, data: Data, maxPixelSize: Int) -> CGImage? {
        guard !Task.isCancelled, maxPixelSize > 0 else { return nil }
        let key = "\(id):\(maxPixelSize)"
        access &+= 1
        if var entry = entries[key] {
            entry.access = access
            entries[key] = entry
            return entry.image
        }

        return autoreleasepool {
            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
            let thumbnailOptions = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions),
                  !Task.isCancelled else { return nil }
            let cost = image.bytesPerRow * image.height
            guard cost <= costLimit else { return image }
            while totalCost + cost > costLimit || entries.count >= 100 {
                guard let oldest = entries.min(by: { $0.value.access < $1.value.access }) else { break }
                totalCost -= oldest.value.cost
                entries.removeValue(forKey: oldest.key)
            }
            entries[key] = Entry(image: image, cost: cost, access: access)
            totalCost += cost
            return image
        }
    }
}
