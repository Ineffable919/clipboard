//
//  PasteboardModel.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

@Observable
final class PasteboardModel: Identifiable {
    var id: Int64?
    let uniqueId: String
    let pasteboardType: PasteboardType
    let data: Data
    // 截取后转换成Data
    let showData: Data?
    private(set) var timestamp: Int64
    let appPath: String
    let appName: String
    // 搜索文本
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
    private(set) lazy var type = PasteModelType(with: pasteboardType)

    private(set) var group: Int
    private var cachedAttributed: AttributedString?
    private var cachedThumbnail: NSImage?
    private var cachedImageSize: CGSize?
    private var cachedBackgroundColor: Color?
    private var cachedForegroundColor: Color?
    private var cachedFilePaths: [String]?
    private var cachedHasBackgroundColor: Bool = false

    var url: URL? {
        if pasteboardType == .string {
            let urlString = String(data: data, encoding: .utf8) ?? ""
            return urlString.asCompleteURL()
        }
        return nil
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
        group: Int
    ) {
        self.pasteboardType = pasteboardType
        self.data = data
        self.showData = showData
        uniqueId = data.sha256Hex
        self.timestamp = timestamp
        self.appPath = appPath
        self.appName = appName
        self.searchText = searchText
        self.length = length
        self.group = group
        attributeString =
            NSAttributedString(
                with: showData,
                type: pasteboardType,
            ) ?? NSAttributedString()

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
        guard let item = pasteboard.pasteboardItems?.first else { return nil }

        let app = NSWorkspace.shared.frontmostApplication
        guard let type = item.availableType(from: PasteboardType.supportTypes)
        else { return nil }
        var content: Data?
        if type.isFile() {
            guard let fileURLs = pasteboard.readObjects(
                forClasses: [NSURL.self],
                options: nil,
            ) as? [URL]
            else { return nil }
            let filePaths = fileURLs.map(\.path)
            FileAccessHelper.shared.saveSecurityBookmarks(for: filePaths)
            let filePathsString = filePaths.joined(separator: "\n")
            content = filePathsString.data(using: .utf8) ?? Data()
        } else {
            content = item.data(forType: type)
        }
        guard content != nil else { return nil }

        var showData: Data?
        var showAtt: NSAttributedString?
        var att = NSAttributedString()
        if type.isText() {
            att =
                NSAttributedString(with: content, type: type)
                    ?? NSAttributedString()
            guard !att.string.allSatisfy(\.isWhitespace) else {
                return nil
            }
            showAtt =
                att.length > 250
                    ? att.attributedSubstring(from: NSMakeRange(0, 250)) : att
            showData = showAtt?.toData(with: type)
        }

        self.init(
            pasteboardType: type,
            data: content ?? Data(),
            showData: showData,
            timestamp: Int64(Date().timeIntervalSince1970),
            appPath: app?.bundleURL?.path ?? "",
            appName: app?.localizedName ?? "",
            searchText: att.string,
            length: att.length,
            group: -1,
        )
    }

    func introString() -> String {
        switch type {
        case .none:
            return ""
        case .image:
            guard let imgSize = imageSize() else { return "" }
            return "\(Int(imgSize.width)) × \(Int(imgSize.height)) "
        case .string, .rich:
            if url != nil, PasteUserDefaults.enableLinkPreview {
                return String(data: data, encoding: .utf8) ?? ""
            }
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
        return ClipboardViewModel.shard.chips.first(where: { $0.id == group })
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
        lhs.uniqueId == rhs.uniqueId && lhs.id == rhs.id
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

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}

extension PasteboardModel {
    func itemProvider() -> NSItemProvider {
        ClipboardViewModel.shard.draggingItemId = id

        if type == .string {
            if let str = String(data: data, encoding: .utf8) {
                return NSItemProvider(object: str as NSString)
            }
        }

        let provider = NSItemProvider()

        if type == .rich {
            provider.registerDataRepresentation(
                forTypeIdentifier: pasteboardType.rawValue,
                visibility: .all,
            ) { [weak self] completion in
                guard let data = self?.data else {
                    completion(nil, nil)
                    return nil
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    completion(data, nil)
                }
                return nil
            }
        }

        if type == .image {
            provider.registerDataRepresentation(
                forTypeIdentifier: pasteboardType.rawValue,
                visibility: .all,
            ) { [weak self] completion in
                guard let data = self?.data else {
                    completion(nil, nil)
                    return nil
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    completion(data, nil)
                }
                return nil
            }
            let name = appName + "-" + timestamp.date()
            provider.suggestedName = name
        }

        if type == .file {
            if let paths = cachedFilePaths {
                for path in paths {
                    let fileURL = URL(fileURLWithPath: path)
                    let promisedType: String = promisedTypeIdentifier(
                        for: fileURL,
                    )
                    provider.registerFileRepresentation(
                        forTypeIdentifier: promisedType,
                        fileOptions: [],
                        visibility: .all,
                    ) { completion in
                        DispatchQueue.global(qos: .userInitiated).async {
                            if FileManager.default.fileExists(atPath: path) {
                                completion(fileURL, true, nil)
                            } else {
                                let error = NSError(
                                    domain: NSCocoaErrorDomain,
                                    code: NSFileReadNoSuchFileError,
                                    userInfo: [NSFilePathErrorKey: path]
                                )
                                completion(nil, false, error)
                            }
                        }
                        return nil
                    }
                }

                if paths.count == 1 {
                    provider.suggestedName =
                        URL(fileURLWithPath: paths[0]).lastPathComponent
                } else {
                    provider.suggestedName = "\(paths.count)个文件"
                }
            }
        }

        return provider
    }

    private func promisedTypeIdentifier(for fileURL: URL) -> String {
        do {
            let values = try fileURL.resourceValues(forKeys: [
                .contentTypeKey,
            ])
            if let type = values.contentType {
                return type.identifier
            }
        } catch {
            // ignore and fall through to fallback
        }
        return UTType.data.identifier
    }
}

enum PasteModelType {
    case none
    case image
    case string
    case rich
    case file

    init(with type: PasteboardType) {
        switch type {
        case .rtf, .rtfd:
            self = .rich
        case .string:
            self = .string
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
        case .file: "文件"
        default: ""
        }
    }
}
