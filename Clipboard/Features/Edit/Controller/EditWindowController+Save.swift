//
//  EditWindowController+Save.swift
//  Clipboard
//

import AppKit

extension EditWindowController {
    func saveContent(_ editedContent: EditedContent) {
        guard let model = currentModel, saveTask == nil else { return }
        let inserting = isNewItem
        saveTask = Task {
            defer {
                if !Task.isCancelled { saveTask = nil }
            }
            guard !Task.isCancelled else { return }
            let prepared = await makePasteContent(editedContent)
            guard !Task.isCancelled, currentModel === model else { return }
            guard let content = prepared,
                  !content.searchText.allSatisfy(\.isWhitespace) else {
                closeWindow()
                return
            }
            let text = content.searchText
            let searchText = await Task.detached(priority: .userInitiated) {
                PasteboardModel.normalizeSearchText(text)
            }.value
            guard !Task.isCancelled, currentModel === model else { return }
            if inserting {
                await insertContent(content, searchText: searchText, source: model)
            } else if let id = model.id {
                guard await PasteDataStore.main.updateItemContent(
                    id: id, content: content, searchText: searchText
                ) else { return }
            }
            guard !Task.isCancelled, currentModel === model else { return }
            closeWindow()
        }
    }

    private func makePasteContent(_ content: EditedContent) async -> PasteContent? {
        let type: PasteboardType
        let data: Data
        let showData: Data?
        let text: String
        let length: Int

        switch content {
        case let .plainText(plainText):
            return await Task.detached(priority: .userInitiated) {
                PasteboardTextPreparation.prepareForSave(plainText)
            }.value
        case let .attributedText(attributedText):
            text = attributedText.string
            length = attributedText.length
            type = Self.hasRichTextAttributes(attributedText) ? .rtf : .string
            data = if type == .string {
                Data(text.utf8)
            } else {
                attributedText.toData(with: type) ?? Data()
            }
            let preview = length > 250
                ? attributedText.attributedSubstring(
                    from: NSRange(location: 0, length: 250)
                )
                : attributedText
            showData = preview.toData(with: type)
        }

        return PasteContent(
            type: type,
            data: data,
            showData: showData,
            searchText: text,
            length: length,
            tag: PasteboardModel.calculateTag(type: type, content: data)
        )
    }

    private func insertContent(
        _ content: PasteContent,
        searchText: String,
        source: PasteboardModel
    ) async {
        let data = content.data
        let uniqueId: String?
        if content.type == .string {
            uniqueId = await Task.detached(priority: .userInitiated) {
                data.sha256Hex
            }.value
        } else {
            uniqueId = nil
        }
        guard !Task.isCancelled, currentModel === source else { return }
        let model = PasteboardModel(
            pasteboardType: content.type,
            data: content.data,
            showData: content.showData,
            timestamp: Int64(Date().timeIntervalSince1970),
            appPath: source.appPath,
            appName: source.appName,
            searchText: searchText,
            length: content.length,
            group: -1,
            tag: content.tag,
            uniqueId: uniqueId,
            appID: source.appID,
            sourceBundleID: source.sourceBundleID
        )

        await PasteDataStore.main.insertModel(model)
    }

    private static func hasRichTextAttributes(
        _ attributedString: NSAttributedString
    ) -> Bool {
        guard attributedString.length > 0 else { return false }

        let range = NSRange(location: 0, length: attributedString.length)
        var found = false
        attributedString.enumerateAttributes(
            in: range,
            options: []
        ) { attributes, _, stop in
            if let underline = attributes[.underlineStyle] as? Int,
               underline != 0 {
                found = true
                stop.pointee = true
                return
            }

            if let strikethrough = attributes[.strikethroughStyle] as? Int,
               strikethrough != 0 {
                found = true
                stop.pointee = true
                return
            }

            if let font = attributes[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.bold) || traits.contains(.italic) {
                    found = true
                    stop.pointee = true
                }
            }
        }
        return found
    }
}
