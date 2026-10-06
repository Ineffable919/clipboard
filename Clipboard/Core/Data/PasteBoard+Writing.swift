import AppKit
import Combine

extension PasteBoard {
    /// 将多个项目合并写入系统剪贴板
    /// 文本类型会用换行符拼接，文件类型会合并 URL，其他类型只写入第一个
    func pasteMultipleData(
        _ items: [PasteboardModel],
        isAttribute: Bool = true,
        showTip: Bool = false,
        copy: Bool = false
    ) {
        guard !items.isEmpty else { return }

        for item in items {
            item.updateDate()
            if let itemId = item.id {
                PasteDataStore.main.updateDbItem(id: itemId, item: item)
            }
        }

        pasteModel = items[0]
        NSPasteboard.general.clearContents()

        let success = writeMultipleToPasteboard(items, isAttribute: isAttribute)
        guard success else { return }

        PasteDataStore.main.moveItemsToFirst(items)
        SoundManager.shared.play(.paste)
        if showTip {
            Task { @MainActor in
                copy ? HUDManager.shared.showCopySucceeded() : HUDManager.shared.showPasteSucceeded()
            }
        }
    }

    /// 将多个项目合并写入剪贴板
    private func writeMultipleToPasteboard(
        _ items: [PasteboardModel],
        isAttribute: Bool
    ) -> Bool {
        let shouldPasteAsPlainText =
            !isAttribute || PasteUserDefaults.pasteOnlyText

        let textItems = items.filter { $0.pasteboardType.isText() }
        let fileItems = items.filter { $0.type == .file }
        let imageItems = items.filter { $0.pasteboardType.isImage() }

        // 文件类型
        if !fileItems.isEmpty {
            if !isAttribute {
                let paths = fileItems.flatMap { $0.cachedFilePaths ?? [] }
                guard !paths.isEmpty else { return false }
                NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
                return true
            }
            return writeMultipleFileURLs(fileItems)
        }

        // 图片类型
        if !imageItems.isEmpty {
            if !isAttribute {
                let text = imageItems.map(\.searchText).filter { !$0.isEmpty }.joined(separator: "\n")
                guard !text.isEmpty else { return false }
                NSPasteboard.general.setString(text, forType: .string)
                return true
            }
            return writeMultipleImages(imageItems)
        }

        // 文本类型合并
        if !textItems.isEmpty {
            if shouldPasteAsPlainText {
                return writeMultiplePlainText(textItems)
            } else {
                return writeMultipleRichText(textItems)
            }
        }

        return false
    }

    /// 合并多个纯文本
    private func writeMultiplePlainText(_ items: [PasteboardModel]) -> Bool {
        let texts = items.compactMap { item -> String? in
            var text = item.plainText
            if PasteUserDefaults.removeTailingNewline {
                text = text.trimmingTrailingNewlines()
            }
            return text.isEmpty ? nil : text
        }
        guard !texts.isEmpty else { return false }

        let combined = texts.joined(separator: "\n")
        NSPasteboard.general.setString(combined, forType: .string)
        return true
    }

    /// 合并多个富文本
    private func writeMultipleRichText(_ items: [PasteboardModel]) -> Bool {
        let combined = NSMutableAttributedString()
        let newline = NSAttributedString(string: "\n")

        for (index, item) in items.enumerated() {
            if let attr = NSAttributedString(
                with: item.data,
                type: item.pasteboardType
            ) {
                let mutable = NSMutableAttributedString(attributedString: attr)
                if PasteUserDefaults.removeTailingNewline {
                    mutable.trimTrailingNewlines()
                }
                combined.append(mutable)
                if index < items.count - 1 {
                    combined.append(newline)
                }
            } else {
                var text = item.plainText
                if PasteUserDefaults.removeTailingNewline {
                    text = text.trimmingTrailingNewlines()
                }
                combined.append(NSAttributedString(string: text))
                if index < items.count - 1 {
                    combined.append(newline)
                }
            }
        }

        guard combined.length > 0 else { return false }

        let rtfType = items.first?.pasteboardType ?? .rtf
        if let data = combined.toData(with: rtfType) {
            NSPasteboard.general.setData(data, forType: rtfType)
        } else {
            NSPasteboard.general.setString(combined.string, forType: .string)
        }
        return true
    }

    /// 合并多个文件 URL
    private func writeMultipleFileURLs(_ items: [PasteboardModel]) -> Bool {
        let fileManager = FileManager.default
        var allURLs: [URL] = []

        for item in items {
            guard let filePaths = String(data: item.data, encoding: .utf8)
            else {
                continue
            }
            let urls =
                filePaths
                    .components(separatedBy: "\n")
                    .lazy
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && fileManager.fileExists(atPath: $0) }
                    .map { URL(fileURLWithPath: $0) }
            allURLs.append(contentsOf: urls)
        }

        guard !allURLs.isEmpty else { return false }
        pasteboard.writeObjects(allURLs as [NSPasteboardWriting])
        return true
    }

    /// 多张图片写入剪贴板：先写为临时文件，再以文件 URL 方式写入（确保目标应用能接收全部图片）
    private func writeMultipleImages(_ items: [PasteboardModel]) -> Bool {
        let tempDir = FileManager.default.temporaryDirectory
            .appending(path: "ClipboardPaste")

        // 清理旧的临时目录
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        var fileURLs: [URL] = []
        for (index, item) in items.enumerated() {
            let ext = item.pasteboardType == .png ? "png" : "tiff"
            let fileName = "image_\(index + 1).\(ext)"
            let fileURL = tempDir.appending(path: fileName)
            do {
                try item.data.write(to: fileURL)
                fileURLs.append(fileURL)
            } catch {
                log.error("写入临时图片文件失败: \(error)")
            }
        }

        guard !fileURLs.isEmpty else { return false }
        pasteboard.writeObjects(fileURLs as [NSPasteboardWriting])

        // 粘贴完成后延迟清理临时文件，给目标应用足够时间读取
        let cleanupDir = tempDir
        Task.detached {
            try? await Task.sleep(for: .seconds(10))
            try? FileManager.default.removeItem(at: cleanupDir)
        }

        return true
    }

    /// 将数据写入系统剪贴板
    /// - Returns: 是否成功写入
    func writeToPasteboard(_ data: PasteboardModel, isAttribute: Bool)
        -> Bool {
        let shouldPasteAsPlainText =
            !isAttribute || PasteUserDefaults.pasteOnlyText

        if data.pasteboardType.isText(), shouldPasteAsPlainText {
            writePlainText(data)
            return true
        }
        if data.type == .file {
            return writeFileURLs(data)
        }
        writeRawData(data)
        return true
    }

    /// 写入纯文本
    private func writePlainText(_ data: PasteboardModel) {
        var text = data.plainText
        if PasteUserDefaults.removeTailingNewline {
            text = text.trimmingTrailingNewlines()
        }
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// 写入文件 URL
    /// - Returns: 是否有有效文件写入
    private func writeFileURLs(_ data: PasteboardModel) -> Bool {
        guard let filePaths = String(data: data.data, encoding: .utf8) else {
            return false
        }

        let fileManager = FileManager.default
        let validURLs =
            filePaths
                .components(separatedBy: "\n")
                .lazy
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && fileManager.fileExists(atPath: $0) }
                .map { URL(fileURLWithPath: $0) }

        let urlArray = Array(validURLs)
        guard !urlArray.isEmpty else { return false }

        pasteboard.writeObjects(urlArray as [NSPasteboardWriting])
        return true
    }

    /// 写入原始数据（富文本、图片等）
    private func writeRawData(_ data: PasteboardModel) {
        // 处理需要去除末尾换行的富文本
        if data.pasteboardType.isText(),
           PasteUserDefaults.removeTailingNewline,
           let attributedString = NSAttributedString(
               with: data.data,
               type: data.pasteboardType
           ) {
            let mutableString = NSMutableAttributedString(
                attributedString: attributedString
            )
            mutableString.trimTrailingNewlines()

            if let processedData = mutableString.toData(
                with: data.pasteboardType
            ) {
                NSPasteboard.general.setData(
                    processedData,
                    forType: data.pasteboardType
                )
                return
            }
        }

        NSPasteboard.general.setData(data.data, forType: data.pasteboardType)
    }}

// MARK: - NSMutableAttributedString Extension

extension NSMutableAttributedString {
    func trimTrailingNewlines() {
        var currentLength = length
        while currentLength > 0 {
            let lastCharRange = NSRange(location: currentLength - 1, length: 1)
            let lastChar = attributedSubstring(from: lastCharRange).string

            if lastChar == "\n" || lastChar == "\r" {
                currentLength -= 1
            } else {
                break
            }
        }

        if currentLength < length {
            deleteCharacters(
                in: NSRange(
                    location: currentLength,
                    length: length - currentLength
                )
            )
        }
    }
}
