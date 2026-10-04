import AppKit

enum PasteboardTextPreparation {
    nonisolated static func prepareForSave(_ text: String) -> PasteContent? {
        guard !text.allSatisfy(\.isWhitespace) else { return nil }
        let data = Data(text.utf8)
        return PasteContent(
            type: .string,
            data: data,
            showData: Data(text.prefix(250).utf8),
            searchText: text,
            length: text.utf16.count,
            tag: PasteboardModel.calculateTextTag(text)
        )
    }

    nonisolated struct Content: Sendable {
        let showData: Data
        let searchText: String
        let length: Int
        let uniqueId: String
    }

    nonisolated static func prepare(_ data: Data) -> Content? {
        autoreleasepool {
            guard let text = String(data: data, encoding: .utf8),
                  !text.allSatisfy(\.isWhitespace) else { return nil }
            let preview = NSAttributedString(string: String(text.prefix(300)))
            let showText = preview.attributedSubstring(from: NSRange(location: 0, length: min(300, preview.length)))
            return Content(
                showData: showText.string.data(using: .utf8) ?? Data(),
                searchText: PasteboardModel.normalizeSearchText(text),
                length: text.utf16.count,
                uniqueId: data.sha256Hex
            )
        }
    }
}
