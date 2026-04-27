//
//  PasteboardModel.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import UniformTypeIdentifiers

final class PasteboardModel: Identifiable, Codable {
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
    private(set) lazy var attributeString: NSAttributedString =
        .init(with: showData, type: pasteboardType) ?? NSAttributedString()

    private(set) lazy var writeItem = PasteboardWritingItem(
        data: data,
        type: pasteboardType,
        plainText: plainText,
        appName: appName,
        timestamp: timestamp,
        model: self
    )
    private(set) lazy var type = PasteModelType(
        with: pasteboardType,
        model: self
    )

    private(set) var group: Int
    let tag: String
    private(set) var hidden: Bool
    var cachedThumbnail: NSImage?
    var cachedImageSize: CGSize?
    var cachedBackgroundColor: NSColor?
    var cachedForegroundColor: NSColor?
    var cachedFilePaths: [String]?
    var cachedOCRRegions: [OCRTextRegion]?
    var cachedOCRKeyword: String?
    var cachedHasBackgroundColor: Bool = false
    var cachedNeedsBottomMask: Bool?
    var cachedDragPreviewRichImage: NSImage?
    var thumbnailLoadTask: Task<NSImage?, Never>?
    /// 链接预览元数据缓存
    var cachedLinkMetadata: LinkPreviewMetadata?

    var hasBgColor: Bool {
        cachedHasBackgroundColor
    }

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
        tag: String,
        hidden: Bool = false
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
        self.hidden = hidden

        uniqueId = Self.generateUniqueId(
            for: pasteboardType,
            data: data
        )

        if pasteboardType == .fileURL {
            if let urlString = String(data: data, encoding: .utf8) {
                cachedFilePaths = urlString.components(separatedBy: "\n")
                    .filter { !$0.isEmpty }
            }
        }

        if pasteboardType == .png || pasteboardType == .tiff {
            cachedImageSize = Self.computeImageSize(from: data)
        }

        let (bg, fg, hasBg) = computeColors()
        cachedBackgroundColor = bg
        cachedForegroundColor = fg
        cachedHasBackgroundColor = hasBg
    }

    // MARK: - 纯文本（粘贴用）

    var plainText: String {
        if pasteboardType.isText() {
            let att = NSAttributedString(with: data, type: pasteboardType)
            return att?.string ?? (String(data: data, encoding: .utf8) ?? "")
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - 搜索文本格式化

    static func normalizeSearchText(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacing(/[\p{Cc}\p{Cf}&&[^\t\n]]/, with: "")
            .replacing(/\s+/, with: " ")
    }

    // MARK: - 辅助

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
            return String(localized: .textCount(length))
        case .string, .rich:
            return String(localized: .textCount(length))
        case .file:
            guard let filePaths = cachedFilePaths else { return "" }
            return filePaths.count > 1
                ? String(localized: .fileCount(filePaths.count))
                : (filePaths.first ?? "")
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

    func updateHidden(val: Bool) {
        hidden = val
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

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, uniqueId, pasteboardType, data, showData, timestamp
        case appPath, appName, searchText, length, group, tag, hidden
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(uniqueId, forKey: .uniqueId)
        try container.encode(pasteboardType.rawValue, forKey: .pasteboardType)
        try container.encode(data, forKey: .data)
        try container.encodeIfPresent(showData, forKey: .showData)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(appPath, forKey: .appPath)
        try container.encode(appName, forKey: .appName)
        try container.encode(searchText, forKey: .searchText)
        try container.encode(length, forKey: .length)
        try container.encode(group, forKey: .group)
        try container.encode(tag, forKey: .tag)
        try container.encode(hidden, forKey: .hidden)
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let pasteboardTypeRaw = try container.decode(
            String.self,
            forKey: .pasteboardType
        )

        try self.init(
            pasteboardType: PasteboardType(pasteboardTypeRaw),
            data: container.decode(Data.self, forKey: .data),
            showData: container.decodeIfPresent(Data.self, forKey: .showData),
            timestamp: container.decode(Int64.self, forKey: .timestamp),
            appPath: container.decode(String.self, forKey: .appPath),
            appName: container.decode(String.self, forKey: .appName),
            searchText: container.decode(String.self, forKey: .searchText),
            length: container.decode(Int.self, forKey: .length),
            group: container.decode(Int.self, forKey: .group),
            tag: container.decode(String.self, forKey: .tag),
            hidden: container.decode(Bool.self, forKey: .hidden)
        )

        id = try container.decodeIfPresent(Int64.self, forKey: .id)
    }
}

// MARK: - Equatable & Hashable

extension PasteboardModel: Equatable {
    static func == (lhs: PasteboardModel, rhs: PasteboardModel) -> Bool {
        lhs.uniqueId == rhs.uniqueId
    }
}

extension PasteboardModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(uniqueId)
        hasher.combine(group)
    }
}
