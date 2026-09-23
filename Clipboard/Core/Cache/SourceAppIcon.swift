import AppKit

/// 80pt 卡片在 Retina 屏上需要至少 160px，使用 256px 覆盖各处显示尺寸。
nonisolated enum SourceAppIcon {
    static let pixelSize = 256
    static let cacheCost = pixelSize * pixelSize * 4

    /// 在后台按需读取；旧图仅在原应用仍可用时更新，不放大低清数据冒充高清图。
    static func read(data: Data?, path: String) -> (image: NSImage?, data: Data?) {
        let stored = data.flatMap { NSBitmapImageRep(data: $0) }?.cgImage
        if let stored, stored.width >= pixelSize, stored.height >= pixelSize {
            return (image(from: stored), nil)
        }
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else {
            return (stored.map { image(from: $0) }, nil)
        }
        let icon = NSWorkspace.shared.icon(forFile: path)
        let size = NSSize(width: pixelSize, height: pixelSize)
        // 明确请求大尺寸表示，避免先取得默认 32px 图像再放大。
        icon.size = size
        var rect = NSRect(origin: .zero, size: size)
        guard let source = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil),
              let context = CGContext(data: nil, width: pixelSize, height: pixelSize, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return (stored.map { image(from: $0) } ?? icon, nil) }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(origin: .zero, size: size))
        guard let scaled = context.makeImage() else { return (icon, nil) }
        let png = NSBitmapImageRep(cgImage: scaled).representation(using: .png, properties: [:])
        return (image(from: scaled), png)
    }

    private static func image(from source: CGImage) -> NSImage {
        NSImage(cgImage: source, size: NSSize(width: 128, height: 128))
    }
}
