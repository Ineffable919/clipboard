//
//  PasteboardWritingItem.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit

final class PasteboardWritingItem: NSObject {
    private let data: Data
    private let type: PasteboardType
    private let searchText: String
    private let appName: String
    private let timestamp: Int64

    init(data: Data, type: PasteboardType, searchText: String = "", appName: String = "", timestamp: Int64 = 0) {
        self.data = data
        self.type = type
        self.searchText = searchText
        self.appName = appName
        self.timestamp = timestamp
    }
}

extension PasteboardWritingItem: NSPasteboardWriting {
    func writableTypes(for _: NSPasteboard) -> [PasteboardType] {
        if type.isFile() {
            return [.fileURL]
        }
        if type.isImage() {
            return [type, .fileURL]
        }
        // 文本类型：提供原始类型 + 纯文本回退
        if type == .string {
            return [.string]
        }
        return [type, .string]
    }

    func pasteboardPropertyList(forType requestedType: PasteboardType) -> Any? {
        if type.isFile() {
            return filePropertyList()
        }
        if type.isImage(), requestedType == .fileURL {
            return imageAsFileURL()
        }
        if requestedType == .string, type != .string {
            return searchText as NSString
        }
        return data
    }

    // MARK: - Private

    /// 将存储的文件路径转为 file:// URL 字符串（Finder 需要的格式）
    private func filePropertyList() -> Any? {
        guard let pathString = String(data: data, encoding: .utf8) else {
            return nil
        }
        let firstPath = pathString
            .components(separatedBy: "\n")
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstPath else { return nil }
        let url = URL(fileURLWithPath: firstPath)
        return url.absoluteString as NSString
    }

    /// 将图片数据写入临时文件，返回 file:// URL 字符串供 Finder 接收
    private func imageAsFileURL() -> Any? {
        let ext = type == .png ? "png" : "tiff"
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let iso = date.formatted(
            Date.ISO8601FormatStyle()
                .year().month().day()
                .dateTimeSeparator(.space)
                .time(includingFractionalSeconds: false)
                .timeSeparator(.colon)
        )

        let safeDateString = iso.replacing(":", with: ".")
        let name = appName.isEmpty ? "Image" : appName
        let fileName = "\(name) \(safeDateString).\(ext)"

        let tempURL = FileManager.default.temporaryDirectory
            .appending(path: "ClipboardDrag")
            .appending(path: fileName)

        let dir = tempURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: tempURL)

        return tempURL.absoluteString as NSString
    }
}
