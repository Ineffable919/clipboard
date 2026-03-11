//
//  PasteboardModel.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class PasteboardModel: Identifiable {
    var id: Int64?
    let uniqueId: String
    let pasteboardType: PasteboardType
    let data: Data
    let showData: Data?
    private(set) var timestamp: Int64
    let appPath: String
    let appName: String
    private(set) var searchText: String
    let length: Int
    /// 截取后的富文本
    let attributeString: NSAttributedString

    @ObservationIgnored
    private(set) lazy var writeItem = PasteboardWritingItem(
        data: data,
        type: pasteboardType
    )
    @ObservationIgnored
    private(set) lazy var type = PasteModelType(
        with: pasteboardType,
        model: self
    )

    private(set) var group: Int
    let tag: String
    @ObservationIgnored
    var cachedAttributed: AttributedString?
    @ObservationIgnored
    var cachedHighlightedPlainKeyword: String?
    @ObservationIgnored
    var cachedHighlightedPlainText: AttributedString?
    @ObservationIgnored
    var cachedHighlightedRichKeyword: String?
    @ObservationIgnored
    var cachedHighlightedRichText: AttributedString?
    @ObservationIgnored
    var cachedThumbnail: NSImage?
    @ObservationIgnored
    var cachedImageSize: CGSize?
    @ObservationIgnored
    var cachedBackgroundColor: Color?
    @ObservationIgnored
    var cachedForegroundColor: Color?
    @ObservationIgnored
    var cachedFilePaths: [String]?
    @ObservationIgnored
    var cachedHasBackgroundColor: Bool = false
    @ObservationIgnored
    var cachedNeedsBottomMask: Bool?
    @ObservationIgnored
    var thumbnailLoadTask: Task<NSImage?, Never>?

    var isLink: Bool {
        attributeString.string.isLink()
    }

    var isCSS: Bool {
        attributeString.string.isCSSHexColor
    }

    init(
        pasteboardType: PasteboardType,
        data: Data,
        showData: Data?,
        timestamp: Int64,
        appPath: String,
        appName: String,
        searchText: String,
        length: Int,
        group: Int,
        tag: String
    ) {
        self.pasteboardType = pasteboardType
        self.data = data
        self.showData = showData
        self.timestamp = timestamp
        self.appPath = appPath
        self.appName = appName
        self.searchText = searchText
        self.length = length
        self.group = group
        self.tag = tag

        attributeString =
            NSAttributedString(
                with: showData,
                type: pasteboardType
            ) ?? NSAttributedString()

        uniqueId = Self.generateUniqueId(
            for: pasteboardType,
            data: data
        )

        let (bg, fg, hasBg) = computeColors()
        cachedBackgroundColor = bg
        cachedForegroundColor = fg
        cachedHasBackgroundColor = hasBg

        if pasteboardType == .fileURL {
            if let urlString = String(data: data, encoding: .utf8) {
                cachedFilePaths = urlString.components(separatedBy: "\n")
                    .filter { !$0.isEmpty }
            }
        }

        if pasteboardType == .png || pasteboardType == .tiff {
            cachedImageSize = Self.computeImageSize(from: data)
        }
    }

    // MARK: - 计算图片尺寸

    private static func computeImageSize(from data: Data) -> CGSize? {
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

    // MARK: - 展示辅助

    static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    func introString() -> String {
        switch type {
        case .none:
            return ""
        case .image:
            guard let imgSize = imageSize() else { return "" }
            return "\(Int(imgSize.width)) × \(Int(imgSize.height)) "
        case .color:
            return ""
        case .link:
            if PasteUserDefaults.enableLinkPreview {
                return attributeString.string
            }
            return
                "\(PasteboardModel.formatter.string(from: NSNumber(value: length)) ?? "")个字符"
        case .string, .rich:
            return
                "\(PasteboardModel.formatter.string(from: NSNumber(value: length)) ?? "")个字符"
        case .file:
            guard let filePaths = cachedFilePaths else { return "" }
            return filePaths.count > 1
                ? "\(filePaths.count) 个文件" : (filePaths.first ?? "")
        }
    }

    func fileSize() -> Int {
        cachedFilePaths?.count ?? 0
    }

    func imageSize() -> CGSize? {
        cachedImageSize
    }

    func thumbnail() -> NSImage? {
        cachedThumbnail
    }

    func loadThumbnail() async -> NSImage? {
        if let cachedThumbnail { return cachedThumbnail }

        if let existingTask = thumbnailLoadTask {
            return await existingTask.value
        }

        let task = Task<NSImage?, Never> { @MainActor in
            let imageData = data

            let image = await Task.detached(priority: .userInitiated) {
                NSImage(data: imageData)
            }.value

            cachedThumbnail = image
            thumbnailLoadTask = nil
            return image
        }

        thumbnailLoadTask = task
        return await task.value
    }

    // MARK: - 状态更新

    func updateGroup(val: Int) {
        group = val
    }

    func updateDate() {
        timestamp = Int64(Date().timeIntervalSince1970)
    }

    func updateSearchText(val: String) {
        searchText = val
    }

    func getGroupChip() -> CategoryChip? {
        guard group != -1 else { return nil }
        return CategoryChipStore.shared.chips.first(where: { $0.id == group })
    }

    func displayCategoryName() -> String {
        if let chip = getGroupChip() {
            return chip.name
        }
        return type.string
    }
}

// MARK: - Equatable

extension PasteboardModel: Equatable {
    static func == (lhs: PasteboardModel, rhs: PasteboardModel) -> Bool {
        lhs.uniqueId == rhs.uniqueId
    }
}
