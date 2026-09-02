//
//  EditWindowController+Save.swift
//  Clipboard
//

import AppKit

extension EditWindowController {
    func saveContent(_ editedContent: EditedContent) {
        guard let model = currentModel else { return }

        let content = makePasteContent(editedContent)
        guard !content.searchText.allSatisfy(\.isWhitespace) else {
            closeWindow()
            return
        }

        if isNewItem {
            insertContent(content, source: model)
        } else if let id = model.id {
            updateContent(content, id: id)
        }
    }

    private func makePasteContent(_ content: EditedContent) -> PasteContent {
        let type: PasteboardType
        let data: Data
        let showData: Data?
        let text: String
        let length: Int

        switch content {
        case let .plainText(plainText):
            type = .string
            data = Data(plainText.utf8)
            showData = Data(plainText.prefix(250).utf8)
            text = plainText
            length = plainText.utf16.count
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
        source: PasteboardModel
    ) {
        let model = PasteboardModel(
            pasteboardType: content.type,
            data: content.data,
            showData: content.showData,
            timestamp: Int64(Date().timeIntervalSince1970),
            appPath: source.appPath,
            appName: source.appName,
            searchText: PasteboardModel.normalizeSearchText(content.searchText),
            length: content.length,
            group: -1,
            tag: content.tag
        )

        Task {
            await PasteDataStore.main.insertModel(model)
            closeWindow()
        }
    }

    private func updateContent(_ content: PasteContent, id: Int64) {
        Task {
            let updated = await PasteDataStore.main.updateItemContent(
                id: id,
                content: content
            )
            guard updated else { return }
            closeWindow()
        }
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
