//
//  ThumbnailView.swift
//  Clipboard
//
//  Created by crown on 2025/9/24.
//

import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

final class ThumbnailView {
    static let shared = ThumbnailView()
    let maxThumbnailSize: CGFloat = 120
    private let memoryCache = NSCache<NSString, NSImage>()

    init() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 20 * 1024 * 1024 // 20MB
    }

    func clearCache() {
        memoryCache.removeAllObjects()
    }

    var cacheInfo: (count: Int, costLimit: Int) {
        (memoryCache.countLimit, memoryCache.totalCostLimit)
    }
}

extension ThumbnailView {
    func generateFinderStyleThumbnail(
        for fileURL: URL,
        completion: @escaping @Sendable (NSImage?) -> Void
    ) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            DispatchQueue.main.async {
                completion(self.getSystemIcon(for: fileURL))
            }
            return
        }

        if let cachedImage = memoryCache.object(
            forKey: fileURL.absoluteString as NSString
        ) {
            completion(cachedImage)
            return
        }

        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: NSSize(width: maxThumbnailSize, height: maxThumbnailSize),
            scale: scale,
            representationTypes: getRepresentationTypes(for: fileURL)
        )
        request.iconMode = true

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            [weak self] thumbnail, _ in
            guard let self else { return }

            let nsImage = thumbnail?.nsImage

            DispatchQueue.main.async {
                if let nsImage {
                    self.memoryCache.setObject(
                        nsImage,
                        forKey: fileURL.absoluteString as NSString,
                        cost: Int(nsImage.size.width * nsImage.size.height * 4) // 估算内存占用
                    )
                    completion(nsImage)
                } else {
                    let icon = self.getSystemIcon(for: fileURL)
                    completion(icon)
                }
            }
        }
    }

    func generateFinderStyleThumbnail(for fileURL: URL) async -> NSImage? {
        await withCheckedContinuation { continuation in
            generateFinderStyleThumbnail(for: fileURL) { image in
                continuation.resume(returning: image)
            }
        }
    }

    private func getRepresentationTypes(for fileURL: URL)
        -> QLThumbnailGenerator.Request.RepresentationTypes
    {
        guard
            let contentType = try? fileURL.resourceValues(forKeys: [
                .contentTypeKey,
            ]).contentType
        else {
            return .thumbnail
        }

        if contentType.conforms(to: .image) {
            return .thumbnail
        }

        if contentType.conforms(to: .text) || contentType.conforms(to: .pdf)
            || contentType.conforms(to: .rtf)
            || contentType.conforms(to: .sourceCode)
        {
            return [.thumbnail, .icon]
        }

        if contentType.conforms(to: .folder) {
            return .icon
        }

        return .thumbnail
    }

    func getSystemIcon(for fileURL: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: fileURL.path)

        if icon.size.width != maxThumbnailSize
            || icon.size.height != maxThumbnailSize
        {
            let resizedIcon = NSImage(
                size: NSSize(width: maxThumbnailSize, height: maxThumbnailSize)
            )
            resizedIcon.lockFocus()
            icon.draw(
                in: NSRect(
                    x: 0,
                    y: 0,
                    width: maxThumbnailSize,
                    height: maxThumbnailSize
                )
            )
            resizedIcon.unlockFocus()
            return resizedIcon
        }

        return icon
    }

    /// 根据文件扩展名获取系统图标
    func getSystemIcon(for fileExtension: String) -> NSImage {
        let dummyURL = URL(fileURLWithPath: "/tmp/dummy.\(fileExtension)")
        return getSystemIcon(for: dummyURL)
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData)
        else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
