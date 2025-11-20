//
//  PasteboardModel.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import KeyboardShortcuts
import Observation
import SwiftUI

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
        type: pasteboardType
    )
    @ObservationIgnored
    private(set) lazy var type = PasteModelType(with: pasteboardType)

    private(set) var group: Int
    private var cachedAttributed: AttributedString?

    private var vm = ClipboardViewModel.shard

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
                type: pasteboardType
            ) ?? NSAttributedString()
    }

    convenience init?(with pasteboard: NSPasteboard) {
        guard let item = pasteboard.pasteboardItems?.first else { return nil }

        let app = NSWorkspace.shared.frontmostApplication
        guard let type = item.availableType(from: PasteboardType.supportTypes)
        else { return nil }
        var content: Data?
        if type.isFile() {
            guard
                let fileURLs = pasteboard.readObjects(
                    forClasses: [NSURL.self],
                    options: nil
                ) as? [URL]
            else { return nil }
            let filePaths = fileURLs.map { $0.path }
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
            guard !att.string.allSatisfy({ $0.isWhitespace }) else {
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
            group: -1
        )
    }

    private let formatter: NumberFormatter = {
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
        case .string, .rich:
            if url != nil && PasteUserDefaults.enableLinkPreview {
                return String(data: data, encoding: .utf8) ?? ""
            }
            return "\(formatter.string(from: NSNumber(value: length)) ?? "")个字符"
        case .file:
            let url = String(data: data, encoding: .utf8)!
            let fileUrls = url.components(separatedBy: "\n").filter {
                !$0.isEmpty
            }
            return fileUrls.count > 1 ? "\(fileUrls.count) 个文件" : url
        }
    }

    func fileSize() -> Int {
        if let url = String(data: data, encoding: .utf8) {
            let fileUrls = url.components(separatedBy: "\n").filter {
                !$0.isEmpty
            }
            return fileUrls.count
        }
        return 0
    }

    func imageSize() -> CGSize? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard
            let source = CGImageSourceCreateWithData(
                data as CFData,
                options
            ),
            let properties = CGImageSourceCopyPropertiesAtIndex(
                source,
                0,
                options
            ) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
            let height = properties[kCGImagePropertyPixelHeight] as? CGFloat
        else {
            return nil
        }
        return CGSize(width: width, height: height)
    }

    func thumbnail(maxPixel: CGFloat = 1024) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                options as CFDictionary
            )
        else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: .zero)
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
        return lhs.uniqueId == rhs.uniqueId
    }
}

extension PasteboardModel {
    var backgroundColor: Color {
        switch type {
        case .string:
            return Color(nsColor: .controlBackgroundColor)
        case .rich:
            if let bgColor = attributeString.attribute(
                .backgroundColor,
                at: 0,
                effectiveRange: nil
            ) as? NSColor {
                return Color(nsColor: bgColor)
            } else {
                return Color(nsColor: .controlBackgroundColor)
            }
        case .image:
            return .clear
        default:
            return Color(nsColor: .controlBackgroundColor)
        }
    }

    // MARK: - 纯函数：根据模型给出背景与前景色

    func colors() -> (
        Color, Color
    ) {
        let fallbackBG = Color(.controlBackgroundColor)
        guard pasteboardType.isText() else {
            return (fallbackBG, .secondary)
        }
        if pasteboardType == .string {
            return (fallbackBG, .secondary)
        }
        if attributeString.length > 0,
           let bg = attributeString.attribute(
               .backgroundColor,
               at: 0,
               effectiveRange: nil
           ) as? NSColor
        {
            return (Color(bg), getRTFColor(baseNS: bg))
        }
        return (fallbackBG, .secondary)
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
        let a = AttributedString(attributeString)
        cachedAttributed = a
        return a
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
        case .image: return "图片"
        case .string, .rich: return "文本"
        case .file: return "文件"
        default: return ""
        }
    }
}
