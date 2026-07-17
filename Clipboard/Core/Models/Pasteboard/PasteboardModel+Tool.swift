//
//  PasteboardModel+Tool.swift
//  Clipboard
//
//  Created by crown on 2026/3/11.
//

import AppKit

extension PasteboardModel {
    static func generateUniqueId(
        for type: PasteboardType,
        data: Data
    ) -> String {
        switch type {
        case .png, .tiff:
            let prefix = data.prefix(1024)
            return "\(prefix.sha256Hex)-\(data.count)"
        case .rtf, .rtfd:
            if let attributeString = NSAttributedString(with: data, type: type),
               let textData = attributeString.string.data(using: .utf8)
            {
                return textData.sha256Hex
            }
            return data.sha256Hex
        default:
            return data.sha256Hex
        }
    }

    /// 加载匹配关键字的 OCR 高亮区域
    func loadOCRHighlightRegions(keyword: String) async -> [OCRTextRegion] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if cachedOCRKeyword == trimmed, let cachedOCRRegions {
            return cachedOCRRegions
        }

        let regions = await OCRViewService.shared.recognizeHighlightRegions(
            from: data,
            keyword: trimmed
        )
        cachedOCRKeyword = trimmed
        cachedOCRRegions = regions
        return regions
    }

    // MARK: - 计算图片尺寸

    static func computeImageSize(from data: Data) -> CGSize? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard
            let source = CGImageSourceCreateWithData(data as CFData, options),
            let properties = CGImageSourceCopyPropertiesAtIndex(
                source,
                0,
                options
            ) as? [CFString: Any]
        else {
            return nil
        }

        let width: CGFloat
        let height: CGFloat

        if let w = properties[kCGImagePropertyPixelWidth] as? Int {
            width = CGFloat(w)
        } else if let w = properties[kCGImagePropertyPixelWidth] as? CGFloat {
            width = w
        } else {
            return nil
        }

        if let h = properties[kCGImagePropertyPixelHeight] as? Int {
            height = CGFloat(h)
        } else if let h = properties[kCGImagePropertyPixelHeight] as? CGFloat {
            height = h
        } else {
            return nil
        }

        let dpi = properties[kCGImagePropertyDPIWidth] as? CGFloat ?? 72.0
        let scale = dpi / 72.0

        return CGSize(width: width / scale, height: height / scale)
    }
}

extension [PasteboardModel] {
    /// 按 `uniqueId` 去重，保留首次出现的元素。
    /// diffable data source 以 `uniqueId` 作为标识符，重复标识符会直接崩溃，
    /// 历史脏数据（存储 unique_id 与运行时重算值不一致）可能产生内容相同的多行，
    /// 在送入 snapshot 前必须去重。
    func deduplicatedByUniqueId() -> [PasteboardModel] {
        var seen = Set<String>()
        return filter { seen.insert($0.uniqueId).inserted }
    }
}
