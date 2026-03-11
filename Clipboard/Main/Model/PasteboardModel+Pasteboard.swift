//
//  PasteboardModel+Pasteboard.swift
//  Clipboard
//
//  Created by crown on 2026/3/11.
//

import AppKit

extension PasteboardModel {
    convenience init?(with pasteboard: NSPasteboard) {
        guard let items = pasteboard.pasteboardItems, !items.isEmpty
        else { return nil }
        let item = items[0]

        let type: PasteboardType
        if let paths = Self.extractFilePaths(from: pasteboard, item: item),
           !paths.isEmpty
        {
            type = .fileURL
        } else if let matched = item.availableType(from: PasteboardType.supportTypes) {
            type = matched
        } else {
            return nil
        }

        var content: Data?
        var searchText = ""
        var length = 0

        if type.isFile() {
            guard let paths = Self.extractFilePaths(from: pasteboard, item: item),
                  !paths.isEmpty
            else { return nil }

            searchText = paths.joined(separator: "")

            let filePathsString = paths.joined(separator: "\n")
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
                length > 300
                    ? att.attributedSubstring(from: NSMakeRange(0, 300)) : att
            showData = showAtt?.toData(with: type)
            searchText = att.string
        }

        let calculatedTag = Self.calculateTag(
            type: type,
            content: content ?? Data()
        )

        let app = NSWorkspace.shared.frontmostApplication

        self.init(
            pasteboardType: type,
            data: content ?? Data(),
            showData: showData ?? Data(),
            timestamp: Int64(Date().timeIntervalSince1970),
            appPath: app?.bundleURL?.path ?? "",
            appName: app?.localizedName ?? "",
            searchText: searchText,
            length: length,
            group: -1,
            tag: calculatedTag
        )
    }

    // MARK: - 从剪贴板提取文件路径

    /// 从剪贴板提取文件路径（兼容跨平台应用）
    ///
    /// 优先级：
    /// 1. 标准 NSURL readObjects
    /// 2. Apple URL pasteboard type 中的 file: URL
    /// 3. x-special/gnome-copied-files 中的 file: URL
    /// 4. 通用兜底：遍历所有类型，查找 file: URL 字符串
    static func extractFilePaths(
        from pasteboard: NSPasteboard,
        item: NSPasteboardItem
    ) -> [String]? {
        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !urls.isEmpty {
            return urls.map(\.path)
        }

        let appleURLType = NSPasteboard.PasteboardType("Apple URL pasteboard type")
        if let paths = parseFileURLStrings(from: item, type: appleURLType) {
            return paths
        }

        let gnomeType = NSPasteboard.PasteboardType("x-special/gnome-copied-files")
        if let str = item.string(forType: gnomeType) {
            let lines = str.components(separatedBy: "\n")
                .dropFirst()
            let paths = lines.compactMap { extractPathFromFileURL($0) }
            if !paths.isEmpty { return paths }
        }

        let skipTypes: Set<String> = [
            NSPasteboard.PasteboardType.string.rawValue,
            NSPasteboard.PasteboardType.rtf.rawValue,
            NSPasteboard.PasteboardType.rtfd.rawValue,
            "public.utf8-plain-text",
        ]
        for itemType in item.types where !skipTypes.contains(itemType.rawValue) {
            if let str = item.string(forType: itemType) ?? (item.propertyList(forType: itemType) as? String) {
                let paths = str.components(separatedBy: "\n")
                    .compactMap { extractPathFromFileURL($0) }
                if !paths.isEmpty { return paths }
            }
        }

        return nil
    }

    private static func parseFileURLStrings(
        from item: NSPasteboardItem,
        type: NSPasteboard.PasteboardType
    ) -> [String]? {
        guard let str = item.string(forType: type) else { return nil }
        let paths = str.components(separatedBy: "\n")
            .compactMap { extractPathFromFileURL($0) }
        return paths.isEmpty ? nil : paths
    }

    private static func extractPathFromFileURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("file:") else { return nil }

        if let url = URL(string: trimmed), url.isFileURL {
            return url.path
        }

        let stripped = trimmed.replacing("file:", with: "")
        let path = stripped.hasPrefix("//")
            ? String(stripped.dropFirst(2))
            : stripped
        return path.hasPrefix("/") ? path : nil
    }

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
}
