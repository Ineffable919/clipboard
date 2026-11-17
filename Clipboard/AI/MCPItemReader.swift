//
//  MCPItemReader.swift
//  Clipboard
//
//  Created by crown on 2026/11/17
//

import AppKit
import ImageIO
import UniformTypeIdentifiers

/// 把数据库中的条目原始数据转换成 MCP 可返回的文本或图片
nonisolated enum MCPItemReader {
    /// 图片长边上限，兼顾视觉模型识别效果与 token 消耗
    static let maxImagePixel = 1024
    /// 摘要预览的最大字符数
    static let previewLength = 200

    // MARK: - Type

    /// 数据库 tag 值 → 对外类型；纯文本与富文本统一为 text
    static func publicType(forTag tag: String?) -> String {
        switch tag {
        case "link", "image", "file", "color": tag ?? "text"
        default: "text"
        }
    }

    /// 对外类型 → 数据库 tag 值
    static func tags(forType type: String) -> [String]? {
        switch type {
        case "text": ["string", "rich"]
        case "link", "image", "file", "color": [type]
        default: nil
        }
    }

    // MARK: - Text

    /// 按粘贴板类型解码出纯文本
    static func text(from data: Data, pasteboardType: String) -> String {
        switch pasteboardType {
        case NSPasteboard.PasteboardType.rtf.rawValue:
            NSAttributedString(rtf: data, documentAttributes: nil)?.string ?? ""
        case NSPasteboard.PasteboardType.rtfd.rawValue:
            NSAttributedString(rtfd: data, documentAttributes: nil)?.string ?? ""
        default:
            String(data: data, encoding: .utf8) ?? ""
        }
    }

    /// 单行预览：折叠空白并截断
    static func preview(of text: String) -> String {
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard collapsed.count > previewLength else { return collapsed }
        return String(collapsed.prefix(previewLength)) + "…"
    }

    /// 文件条目的预览：首个路径，多文件时附带总数
    static func filePreview(from data: Data) -> String {
        let paths = filePaths(from: data)
        guard let first = paths.first else { return "" }
        return paths.count > 1 ? "\(first) (+\(paths.count - 1) more)" : first
    }

    static func filePaths(from data: Data) -> [String] {
        (String(data: data, encoding: .utf8) ?? "")
            .split(separator: "\n")
            .map(String.init)
    }

    // MARK: - Image

    /// 缩放到长边不超过 `maxImagePixel` 并重新编码为 JPEG；透明区域铺白底
    static func jpegThumbnail(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxImagePixel
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
            let flattened = flatten(thumbnail)
        else { return nil }

        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.8]
        CGImageDestinationAddImage(destination, flattened, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// JPEG 不支持透明通道，直接编码会让透明区域变黑
    private static func flatten(_ image: CGImage) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        else { return nil }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(rect)
        context.draw(image, in: rect)
        return context.makeImage()
    }
}
