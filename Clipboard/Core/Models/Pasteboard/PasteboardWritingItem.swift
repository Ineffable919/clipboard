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
    private let plainText: String
    private let appName: String
    private let timestamp: Int64
    private let model: PasteboardModel?

    init(
        data: Data,
        type: PasteboardType,
        plainText: String = "",
        appName: String = "",
        timestamp: Int64 = 0,
        model: PasteboardModel? = nil
    ) {
        self.data = data
        self.type = type
        self.plainText = plainText
        self.appName = appName
        self.timestamp = timestamp
        self.model = model
    }
}

extension PasteboardWritingItem: NSPasteboardWriting {
    func writableTypes(for _: NSPasteboard) -> [PasteboardType] {
        var types: [PasteboardType] = []

        types.append(.pasteboardModel)

        if type.isFile() {
            types.append(.fileURL)
            return types
        }
        if type.isImage() {
            types.append(contentsOf: [type, .fileURL])
            return types
        }
        if type == .string {
            types.append(.string)
            return types
        }
        types.append(contentsOf: [type, .string])
        return types
    }

    func pasteboardPropertyList(forType requestedType: PasteboardType) -> Any? {
        if requestedType == .pasteboardModel {
            return modelPropertyList()
        }
        if type.isFile() {
            return filePropertyList()
        }
        if type.isImage(), requestedType == .fileURL {
            return imageAsFileURL()
        }
        if requestedType == .string, type != .string {
            return plainText as NSString
        }
        return data
    }

    // MARK: - Private

    private func modelPropertyList() -> Any? {
        guard let model else { return nil }
        guard let jsonData = try? JSONEncoder().encode(model) else {
            return nil
        }
        return jsonData
    }

    /// 将存储的文件路径转为 file:// URL 字符串（Finder 需要的格式）
    private func filePropertyList() -> Any? {
        guard let pathString = String(data: data, encoding: .utf8) else {
            return nil
        }
        let firstPath =
            pathString
                .components(separatedBy: "\n")
                .first {
                    !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }?
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
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        try? data.write(to: tempURL)

        return tempURL.absoluteString as NSString
    }
}
