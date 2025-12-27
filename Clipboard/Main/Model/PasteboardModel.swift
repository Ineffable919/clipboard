//
//  PasteboardModel.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
    let searchText: String
    let length: Int
    // 截取后的富文本
    let attributeString: NSAttributedString

    @ObservationIgnored
    private(set) lazy var writeItem = PasteboardWritingItem(
        data: data,
        type: pasteboardType,
    )
    @ObservationIgnored
    private(set) lazy var type = PasteModelType(
        with: pasteboardType,
        model: self,
    )

    private(set) var group: Int
    let tag: String
    private var cachedAttributed: AttributedString?
    private var cachedHighlightedPlainKeyword: String?
    private var cachedHighlightedPlainText: AttributedString?
    private var cachedHighlightedRichKeyword: String?
    private var cachedHighlightedRichText: AttributedString?
    private var cachedThumbnail: NSImage?
    private var cachedImageSize: CGSize?
    private var cachedBackgroundColor: Color?
    private var cachedForegroundColor: Color?
    var cachedFilePaths: [String]?
    private var cachedHasBackgroundColor: Bool = false

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
                type: pasteboardType,
            ) ?? NSAttributedString()

        uniqueId = Self.generateUniqueId(
            for: pasteboardType,
            data: data,
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
    }

    convenience init?(with pasteboard: NSPasteboard) {
        guard let items = pasteboard.pasteboardItems, !items.isEmpty
        else { return nil }
        let item = items[0]

        guard let type = item.availableType(from: PasteboardType.supportTypes)
        else { return nil }

        var content: Data?
        var searchText = ""
        var length = 0
        var filePaths: [String]?

        if type.isFile() {
            guard
                let fileURLs = pasteboard.readObjects(
                    forClasses: [NSURL.self],
                    options: nil,
                ) as? [URL]
            else { return nil }

            filePaths = fileURLs.map(\.path)
            searchText = filePaths!.joined(separator: "")

            let pathsToSave = filePaths!
            Task.detached(priority: .utility) {
                await FileAccessHelper.shared.saveSecurityBookmarks(
                    for: pathsToSave,
                )
            }

            let filePathsString = filePaths!.joined(separator: "\n")
            content = filePathsString.data(using: .utf8) ?? Data()
        } else {
            content = item.data(forType: type)
        }
        guard content != nil else { return nil }

        var showData: Data?
        var showAtt: NSAttributedString?
        if type.isText() {
            let att =
                NSAttributedString(with: content, type: type)
                    ?? NSAttributedString()
            guard !att.string.allSatisfy(\.isWhitespace) else {
                return nil
            }
            length = att.length
            showAtt =
                length > 250
                    ? att.attributedSubstring(from: NSMakeRange(0, 250)) : att
            showData = showAtt?.toData(with: type)
            searchText = att.string
        }

        let calculatedTag = Self.calculateTag(
            type: type,
            content: content ?? Data(),
        )

        let app = NSWorkspace.shared.frontmostApplication

        self.init(
            pasteboardType: type,
            data: content ?? Data(),
            showData: showData,
            timestamp: Int64(Date().timeIntervalSince1970),
            appPath: app?.bundleURL?.path ?? "",
            appName: app?.localizedName ?? "",
            searchText: searchText,
            length: length,
            group: -1,
            tag: calculatedTag,
        )
    }

    // MARK: - Public Helper

    static func calculateTag(type: PasteboardType, content: Data)
        -> String
    {
        switch type {
        case .rtf, .rtfd:
            if let attr = NSAttributedString(with: content, type: type) {
                if attr.string.isCSSHexColor {
                    return "color"
                }
                if attr.string.asCompleteURL() != nil {
                    return "link"
                }
            }
            return "rich"
        case .string:
            guard let str = String(data: content, encoding: .utf8) else {
                return "string"
            }
            if str.isCSSHexColor {
                return "color"
            } else if str.asCompleteURL() != nil {
                return "link"
            } else {
                return "string"
            }
        case .png, .tiff:
            return "image"
        case .fileURL:
            return "file"
        default:
            return ""
        }
    }

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
        if let cachedImageSize { return cachedImageSize }

        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard
            let source = CGImageSourceCreateWithData(data as CFData, options),
            let properties = CGImageSourceCopyPropertiesAtIndex(
                source,
                0,
                options,
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

        // 获取 DPI
        let dpi = properties[kCGImagePropertyDPIWidth] as? CGFloat ?? 72.0
        let scale = dpi / 72.0

        let size = CGSize(width: width / scale, height: height / scale)
        cachedImageSize = size
        return size
    }

    func thumbnail() -> NSImage? {
        if let cachedThumbnail { return cachedThumbnail }

        let image = NSImage(data: data)
        cachedThumbnail = image
        return image
    }

    func updateGroup(val: Int) {
        group = val
    }

    func updateDate() {
        timestamp = Int64(Date().timeIntervalSince1970)
    }

    func getGroupChip() -> CategoryChip? {
        guard group != -1 else { return nil }
        let allChips =
            CategoryChip.systemChips + PasteUserDefaults.userCategoryChip
        return allChips.first(where: { $0.id == group })
    }

    func displayCategoryName() -> String {
        if let chip = getGroupChip() {
            return chip.name
        }
        return type.string
    }
}

extension PasteboardModel: Equatable {
    static func == (lhs: PasteboardModel, rhs: PasteboardModel) -> Bool {
        lhs.uniqueId == rhs.uniqueId
    }
}

extension PasteboardModel {
    var backgroundColor: Color {
        cachedBackgroundColor ?? .clear
    }

    var hasBgColor: Bool {
        cachedHasBackgroundColor
    }

    // MARK: - 纯函数：根据模型给出背景与前景色

    func colors() -> (Color, Color) {
        (
            cachedBackgroundColor ?? Color(.controlBackgroundColor),
            cachedForegroundColor ?? .secondary,
        )
    }

    private func computeColors() -> (Color, Color, Bool) {
        let fallbackBG = Color(.controlBackgroundColor)
        guard pasteboardType.isText() else {
            return (fallbackBG, .secondary, false)
        }
        if pasteboardType == .string {
            return (fallbackBG, .secondary, false)
        }
        if attributeString.length > 0,
           let bg = attributeString.attribute(
               .backgroundColor,
               at: 0,
               effectiveRange: nil,
           ) as? NSColor
        {
            return (Color(bg), getRTFColor(baseNS: bg), true)
        }
        return (fallbackBG, .secondary, false)
    }

    // 在 sRGB 空间基于亮度粗分
    private func getRTFColor(baseNS: NSColor) -> Color {
        let c = baseNS.usingColorSpace(.sRGB) ?? baseNS
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        let brightness = 0.299 * r + 0.587 * g + 0.114 * b
        return brightness > 0.7
            ? Color.black.opacity(0.5) : Color.white.opacity(0.5)
    }

    func attributed() -> AttributedString {
        if let cachedAttributed { return cachedAttributed }
        let attr = AttributedString(attributeString)
        cachedAttributed = attr
        return attr
    }

    func highlightedPlainText(keyword: String) -> AttributedString {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else {
            return AttributedString(attributeString.string)
        }

        if cachedHighlightedPlainKeyword == trimmedKeyword,
           let cachedHighlightedPlainText
        {
            return cachedHighlightedPlainText
        }

        let source = attributeString.string
        var attributed = AttributedString(source)

        let options: String.CompareOptions = [
            .caseInsensitive,
            .diacriticInsensitive,
            .widthInsensitive,
        ]

        var searchStart = source.startIndex
        while searchStart < source.endIndex,
              let range = source.range(
                  of: trimmedKeyword,
                  options: options,
                  range: searchStart ..< source.endIndex,
                  locale: .current,
              )
        {
            if let attributedRange = Range(range, in: attributed) {
                attributed[attributedRange].backgroundColor =
                    Color.yellow.opacity(0.65)
            }
            searchStart = range.upperBound
        }

        cachedHighlightedPlainKeyword = trimmedKeyword
        cachedHighlightedPlainText = attributed
        return attributed
    }

    func highlightedRichText(keyword: String) -> AttributedString {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else {
            return attributed()
        }

        if cachedHighlightedRichKeyword == trimmedKeyword,
           let cachedHighlightedRichText
        {
            return cachedHighlightedRichText
        }

        let mutable = NSMutableAttributedString(attributedString: attributeString)
        let string = mutable.string as NSString

        let options: NSString.CompareOptions = [
            .caseInsensitive,
            .diacriticInsensitive,
            .widthInsensitive,
        ]

        var searchRange = NSRange(location: 0, length: string.length)
        while searchRange.length > 0 {
            let found = string.range(
                of: trimmedKeyword,
                options: options,
                range: searchRange,
                locale: .current,
            )

            if found.location == NSNotFound {
                break
            }

            mutable.addAttribute(
                .backgroundColor,
                value: NSColor.systemYellow.withAlphaComponent(0.65),
                range: found,
            )

            let nextLocation = found.location + found.length
            guard nextLocation < string.length else { break }
            searchRange = NSRange(
                location: nextLocation,
                length: string.length - nextLocation,
            )
        }

        let highlighted = AttributedString(mutable)
        cachedHighlightedRichKeyword = trimmedKeyword
        cachedHighlightedRichText = highlighted
        return highlighted
    }

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}

extension PasteboardModel {
    func itemProvider() -> NSItemProvider {
        if type == .string || type == .color || type == .link {
            let provider = NSItemProvider()
            let dataCopy = data
            let typeIdentifier = pasteboardType.rawValue
            provider.registerDataRepresentation(
                forTypeIdentifier: typeIdentifier,
                visibility: .all
            ) { completion in
                completion(dataCopy, nil)
                return nil
            }
            return provider
        }

        if type == .rich {
            if #available(macOS 15.0, *) {
                let provider = NSItemProvider()
                let dataCopy = data
                let typeIdentifier = pasteboardType.rawValue
                provider.registerDataRepresentation(
                    forTypeIdentifier: typeIdentifier,
                    visibility: .all
                ) { completion in
                    completion(dataCopy, nil)
                    return nil
                }
                return provider
            } else {
                let provider = NSItemProvider(
                    object: attributeString.string as NSString
                )
                let dataCopy = data
                let typeIdentifier = pasteboardType.rawValue
                provider.registerDataRepresentation(
                    forTypeIdentifier: typeIdentifier,
                    visibility: .all
                ) { completion in
                    completion(dataCopy, nil)
                    return nil
                }
                return provider
            }
        }

        if type == .image {
            let name = appName + "-" + timestamp.date()
            if #available(macOS 15.0, *) {
                let provider = NSItemProvider()
                provider.registerDataRepresentation(
                    forTypeIdentifier: pasteboardType.rawValue,
                    visibility: .all
                ) { [self] completion in
                    completion(data, nil)
                    return nil
                }
                provider.suggestedName = name
                return provider
            } else {
                if let image = NSImage(data: data) {
                    let provider = NSItemProvider(object: image)
                    provider.suggestedName = name
                    return provider
                }
            }
        }

        if type == .file {
            if let paths = cachedFilePaths, !paths.isEmpty {
                let path = paths[0]
                guard path.hasPrefix("/") else {
                    return NSItemProvider()
                }

                let fileURL = URL(fileURLWithPath: path)
                guard fileURL.isFileURL else {
                    return NSItemProvider()
                }

                let hasAccess = fileURL.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }

                if let provider = NSItemProvider(contentsOf: fileURL) {
                    provider.suggestedName =
                        fileURL.deletingPathExtension().lastPathComponent
                    return provider
                }

                return NSItemProvider()
            }
        }

        return NSItemProvider()
    }

    private static func generateUniqueId(
        for type: PasteboardType,
        data: Data,
    ) -> String {
        switch type {
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
}

enum PasteModelType: String {
    case none
    case image
    case string
    case rich
    case file
    case link
    case color

    init(with type: PasteboardType, model: PasteboardModel) {
        switch type {
        case .rtf, .rtfd:
            if model.isCSS {
                self = .color
            } else if model.isLink {
                self = .link
            } else {
                self = .rich
            }
        case .string:
            if model.isCSS {
                self = .color
            } else if model.isLink {
                self = .link
            } else {
                self = .string
            }
        case .png, .tiff:
            self = .image
        case .fileURL:
            self = .file
        default:
            self = .none
        }
    }

    var string: String {
        switch self {
        case .image: "图片"
        case .string, .rich: "文本"
        case .color: "颜色"
        case .link: "链接"
        case .file: "文件"
        default: ""
        }
    }

    var tagValue: String {
        switch self {
        case .none: ""
        case .image: "image"
        case .string: "string"
        case .rich: "rich"
        case .file: "file"
        case .link: "link"
        case .color: "color"
        }
    }

    var iconAndLabel: (icon: String, label: String) {
        switch self {
        case .image:
            ("photo", "图片")
        case .string, .rich:
            ("text.document", "文本")
        case .file:
            ("folder", "文件")
        case .link:
            ("link", "链接")
        case .color:
            ("paintpalette", "颜色")
        case .none:
            ("", "")
        }
    }
}
