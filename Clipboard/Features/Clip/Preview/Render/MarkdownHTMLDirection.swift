//
//  MarkdownHTMLDirection.swift
//  Clipboard
//
//  为从右向左书写的 Markdown 段落补充方向属性。
//

import Foundation

nonisolated enum MarkdownHTMLDirection {
    private static let blockTagRegex: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: #"<(blockquote|p|li|h[1-6])(\s[^>]*)?>"#,
            options: [.caseInsensitive]
        )
    }()

    private static let htmlTagRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: #"<[^>]+>"#)
    }()

    private static let rtlRanges: [ClosedRange<UInt32>] = [
        0x0590...0x05FF, 0x0600...0x06FF, 0x0700...0x074F, 0x0750...0x077F,
        0x0780...0x07BF, 0x07C0...0x07FF, 0x0800...0x083F, 0x0840...0x085F,
        0x08A0...0x08FF, 0xFB50...0xFDFF, 0xFE70...0xFEFF
    ]

    static func sourceMayNeedRTL(_ source: String) -> Bool {
        source.unicodeScalars.contains { scalar in
            scalar.value >= 0x0590
                && scalar.value <= 0xFEFF
                && rtlRanges.contains(where: { $0.contains(scalar.value) })
        }
    }

    static func inject(in html: String) -> String {
        let nsHTML = html as NSString
        let matches = blockTagRegex.matches(
            in: html,
            range: NSRange(location: 0, length: nsHTML.length)
        )
        guard !matches.isEmpty else { return html }

        var output = ""
        output.reserveCapacity(html.count + matches.count * 12)
        var cursor = 0

        for match in matches {
            output += nsHTML.substring(with: NSRange(
                location: cursor,
                length: match.range.location - cursor
            ))
            let tag = nsHTML.substring(with: match.range(at: 1))
            let attributes = match.range(at: 2).location == NSNotFound
                ? ""
                : nsHTML.substring(with: match.range(at: 2))

            if attributes.lowercased().contains("dir=") {
                output += nsHTML.substring(with: match.range)
            } else {
                let contentStart = match.range.location + match.range.length
                let lookahead = min(300, nsHTML.length - contentStart)
                let content = nsHTML.substring(with: NSRange(location: contentStart, length: lookahead))
                let plainText = htmlTagRegex.stringByReplacingMatches(
                    in: content,
                    range: NSRange(location: 0, length: (content as NSString).length),
                    withTemplate: ""
                )
                output += firstStrongCharacter(in: plainText).map(isRTL) == true
                    ? "<\(tag)\(attributes) dir=\"rtl\">"
                    : nsHTML.substring(with: match.range)
            }
            cursor = match.range.location + match.range.length
        }
        output += nsHTML.substring(from: cursor)
        return output
    }

    private static func firstStrongCharacter(in text: String) -> Character? {
        text.first { character in
            guard let scalar = character.unicodeScalars.first else { return false }
            switch scalar.properties.generalCategory {
            case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter,
                 .modifierLetter, .otherLetter, .nonspacingMark,
                 .spacingMark, .enclosingMark:
                return true
            default:
                return false
            }
        }
    }

    private static func isRTL(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        return rtlRanges.contains { $0.contains(scalar.value) }
    }
}
