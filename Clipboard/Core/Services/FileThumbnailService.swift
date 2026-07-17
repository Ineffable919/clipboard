//
//  FileThumbnailService.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

final class FileThumbnailService: @unchecked Sendable {
    static let shared = FileThumbnailService()

    let maxThumbnailSize: CGFloat = 120
    private let memoryCache = NSCache<NSString, NSImage>()

    private init() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 20 * 1024 * 1024
    }

    func clearCache() {
        memoryCache.removeAllObjects()
    }

    // MARK: - Thumbnail generation

    func generateThumbnail(for fileURL: URL) async -> NSImage {
        let key = fileURL.absoluteString as NSString
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return systemIcon(for: fileURL)
        }

        let scale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 1.0 }
        let size = NSSize(width: maxThumbnailSize, height: maxThumbnailSize)
        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: size,
            scale: scale,
            representationTypes: representationTypes(for: fileURL)
        )
        request.iconMode = true

        let image: NSImage
        if let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            let nsImage = rep.nsImage
            memoryCache.setObject(
                nsImage,
                forKey: key,
                cost: Int(nsImage.size.width * nsImage.size.height * 4)
            )
            image = nsImage
        } else {
            image = systemIcon(for: fileURL)
        }
        return image
    }

    func systemIcon(for fileURL: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
        guard icon.size.width != maxThumbnailSize || icon.size.height != maxThumbnailSize else {
            return icon
        }
        let resized = NSImage(size: NSSize(width: maxThumbnailSize, height: maxThumbnailSize))
        resized.lockFocus()
        icon.draw(in: NSRect(x: 0, y: 0, width: maxThumbnailSize, height: maxThumbnailSize))
        resized.unlockFocus()
        return resized
    }

    // MARK: - Private

    private func representationTypes(for fileURL: URL) -> QLThumbnailGenerator.Request.RepresentationTypes {
        guard let contentType = try? fileURL.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return .thumbnail
        }
        if contentType.conforms(to: .image) {
            return .thumbnail
        }
        if contentType.conforms(to: .text) || contentType.conforms(to: .pdf)
            || contentType.conforms(to: .rtf) || contentType.conforms(to: .sourceCode)
        {
            return [.thumbnail, .icon]
        }
        if contentType.conforms(to: .folder) {
            return .icon
        }
        return .thumbnail
    }
}
