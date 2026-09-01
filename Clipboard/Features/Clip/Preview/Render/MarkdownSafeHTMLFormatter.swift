//
//  MarkdownSafeHTMLFormatter.swift
//  Clipboard
//
//  转义 Markdown 生成的文本和属性；原始 HTML 交由 DOMPurify 清理。
//

import Foundation
import Markdown

nonisolated struct MarkdownSafeHTMLFormatter: MarkupVisitor {
    typealias Result = String

    private var inTableHead = false
    private var tableColumnAlignments: [Markdown.Table.ColumnAlignment?]?
    private var currentTableColumn = 0
    private var headingIndex = 0

    static func format(_ markdown: String) -> String {
        var formatter = MarkdownSafeHTMLFormatter()
        return formatter.visit(Document(parsing: markdown))
    }

    mutating func defaultVisit(_ markup: Markup) -> String {
        markup.children.map { visit($0) }.joined()
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        if let alert = renderAlert(blockQuote) {
            return alert
        }
        return "<blockquote>\n\(defaultVisit(blockQuote))</blockquote>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let info = CodeFenceInfo(rawInfoString: codeBlock.language)
        let detectedLanguage = info.language.isEmpty
            ? CodeFenceLanguageDetector.detect(codeBlock.code)
            : nil
        let language = info.language.isEmpty ? detectedLanguage : info.highlightLanguage
        let languageAttribute = language.map {
            " class=\"language-\(escapeAttribute($0))\""
        } ?? ""
        return "<pre><code\(languageAttribute)>\(escapeText(codeBlock.code))</code></pre>\n"
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        defer { headingIndex += 1 }
        return "<h\(heading.level) id=\"md-heading-\(headingIndex)\">\(defaultVisit(heading))</h\(heading.level)>\n"
    }

    mutating func visitThematicBreak(_: ThematicBreak) -> String {
        "<hr />\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String {
        html.rawHTML
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        let checkbox: String
        if let state = listItem.checkbox {
            let checked = state == .checked ? " checked=\"\"" : ""
            checkbox = "<input type=\"checkbox\" class=\"task-list-item-checkbox\" disabled=\"\"\(checked) /> "
        } else {
            checkbox = ""
        }
        let classAttribute = listItem.checkbox == nil ? "" : " class=\"task-list-item\""
        return "<li\(classAttribute)>\(checkbox)\(defaultVisit(listItem))</li>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        let startAttribute = orderedList.startIndex == 1 ? "" : " start=\"\(orderedList.startIndex)\""
        return "<ol\(startAttribute)>\n\(defaultVisit(orderedList))</ol>\n"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        "<ul>\n\(defaultVisit(unorderedList))</ul>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        "<p>\(defaultVisit(paragraph))</p>\n"
    }

    mutating func visitTable(_ table: Markdown.Table) -> String {
        tableColumnAlignments = table.columnAlignments
        defer { tableColumnAlignments = nil }
        return "<table>\n\(defaultVisit(table))</table>\n"
    }

    mutating func visitTableHead(_ tableHead: Markdown.Table.Head) -> String {
        inTableHead = true
        currentTableColumn = 0
        let content = defaultVisit(tableHead)
        inTableHead = false
        return "<thead>\n<tr>\n\(content)</tr>\n</thead>\n"
    }

    mutating func visitTableBody(_ tableBody: Markdown.Table.Body) -> String {
        guard !tableBody.isEmpty else { return "" }
        return "<tbody>\n\(defaultVisit(tableBody))</tbody>\n"
    }

    mutating func visitTableRow(_ tableRow: Markdown.Table.Row) -> String {
        currentTableColumn = 0
        return "<tr>\n\(defaultVisit(tableRow))</tr>\n"
    }

    mutating func visitTableCell(_ tableCell: Markdown.Table.Cell) -> String {
        guard let alignments = tableColumnAlignments,
              currentTableColumn < alignments.count,
              tableCell.rowspan > 0,
              tableCell.colspan > 0
        else {
            return ""
        }

        let element = inTableHead ? "th" : "td"
        let alignmentAttribute = alignments[currentTableColumn].map { " align=\"\($0)\"" } ?? ""
        currentTableColumn += 1
        let rowSpanAttribute = tableCell.rowspan > 1 ? " rowspan=\"\(tableCell.rowspan)\"" : ""
        let columnSpanAttribute = tableCell.colspan > 1 ? " colspan=\"\(tableCell.colspan)\"" : ""
        let attributes = alignmentAttribute + rowSpanAttribute + columnSpanAttribute
        return "<\(element)\(attributes)>\(defaultVisit(tableCell))</\(element)>\n"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>\(escapeText(inlineCode.code))</code>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        "<em>\(defaultVisit(emphasis))</em>"
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        "<strong>\(defaultVisit(strong))</strong>"
    }

    mutating func visitImage(_ image: Image) -> String {
        let sourceAttribute = image.source.map { " src=\"\(escapeAttribute($0))\"" } ?? ""
        let titleAttribute = image.title.map { " title=\"\(escapeAttribute($0))\"" } ?? ""
        let altAttribute = " alt=\"\(escapeAttribute(image.plainText))\""
        return "<img\(sourceAttribute)\(titleAttribute)\(altAttribute) />"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String {
        inlineHTML.rawHTML
    }

    mutating func visitLineBreak(_: LineBreak) -> String {
        "<br />\n"
    }

    mutating func visitSoftBreak(_: SoftBreak) -> String {
        "<br />\n"
    }

    mutating func visitLink(_ link: Link) -> String {
        let destinationAttribute = link.destination.map { " href=\"\(escapeAttribute($0))\"" } ?? ""
        return "<a\(destinationAttribute)>\(defaultVisit(link))</a>"
    }

    mutating func visitText(_ text: Text) -> String {
        escapeText(text.string)
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        "<del>\(defaultVisit(strikethrough))</del>"
    }

    mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> String {
        guard let destination = symbolLink.destination else { return "" }
        return "<code>\(escapeText(destination))</code>"
    }

    mutating func visitInlineAttributes(_ attributes: InlineAttributes) -> String {
        "<span>\(defaultVisit(attributes))</span>"
    }

    private func escapeText(_ string: String) -> String {
        escape(string, includesQuotationMark: false)
    }

    private func escapeAttribute(_ string: String) -> String {
        escape(string, includesQuotationMark: true)
    }

    private func escape(_ string: String, includesQuotationMark: Bool) -> String {
        var output = ""
        output.reserveCapacity(string.count)

        for character in string {
            switch character {
            case "&":
                output += "&amp;"
            case "<":
                output += "&lt;"
            case ">":
                output += "&gt;"
            case "\"" where includesQuotationMark:
                output += "&quot;"
            default:
                output.append(character)
            }
        }
        return output
    }
}

nonisolated extension MarkdownSafeHTMLFormatter {
    // SVG paths and the single-pass alert parser are clearer kept together.
    private mutating func renderAlert(_ blockQuote: BlockQuote) -> String? {
        let blocks = Array(blockQuote.children)
        guard let firstParagraph = blocks.first as? Paragraph else { return nil }
        let inlines = Array(firstParagraph.children)
        guard let firstText = inlines.first as? Text,
              let (kind, prefixLength) = Self.matchAlertTag(firstText.string) else {
            return nil
        }

        var firstTextRest = String(firstText.string.dropFirst(prefixLength))
        if firstTextRest.hasPrefix(" ") {
            firstTextRest.removeFirst()
        }

        let (titleInlines, bodyInlines) = Self.splitAlertInlines(inlines.dropFirst())

        let hasCustomTitle = !firstTextRest.trimmingCharacters(in: .whitespaces).isEmpty
            || !titleInlines.isEmpty
        var html = "<div class=\"markdown-alert markdown-alert-\(kind.rawValue)\">\n"
        html += "<p class=\"markdown-alert-title\">\(kind.iconSVG) "
        if hasCustomTitle {
            html += escapeText(firstTextRest)
            for inline in titleInlines {
                html += visit(inline)
            }
        } else {
            html += kind.rawValue.uppercased()
        }
        html += "</p>\n"

        if !bodyInlines.isEmpty {
            html += "<p>"
            for inline in bodyInlines {
                html += visit(inline)
            }
            html += "</p>\n"
        }
        for block in blocks.dropFirst() {
            html += visit(block)
        }
        html += "</div>\n"
        return html
    }

    private static func splitAlertInlines(
        _ inlines: ArraySlice<Markup>
    ) -> (title: [Markup], body: [Markup]) {
        var title: [Markup] = []
        var body: [Markup] = []
        var passedTitle = false

        for inline in inlines {
            if passedTitle {
                body.append(inline)
            } else if inline is SoftBreak || inline is LineBreak {
                passedTitle = true
            } else {
                title.append(inline)
            }
        }
        return (title, body)
    }

    private static func matchAlertTag(_ text: String) -> (AlertKind, Int)? {
        let lowercased = text.lowercased()
        for kind in AlertKind.allCases {
            let tag = "[!\(kind.rawValue)]"
            if lowercased.hasPrefix(tag) {
                return (kind, tag.count)
            }
        }
        return nil
    }

    private enum AlertKind: String, CaseIterable {
        case note, tip, important, warning, caution

        var iconSVG: String {
            "<svg class=\"markdown-alert-icon\" viewBox=\"0 0 16 16\" width=\"16\" "
                + "height=\"16\" aria-hidden=\"true\"><path d=\"\(iconPath)\"></path></svg>"
        }

        private var iconPath: String {
            switch self {
            case .note:
                "M0 8a8 8 0 1 1 16 0A8 8 0 0 1 0 8Z"
                    + "m8-6.5a6.5 6.5 0 1 0 0 13 6.5 6.5 0 0 0 0-13Z"
                    + "M6.5 7.75A.75.75 0 0 1 7.25 7h1a.75.75 0 0 1 .75.75v2.75h.25"
                    + "a.75.75 0 0 1 0 1.5h-2a.75.75 0 0 1 0-1.5h.25v-2h-.25"
                    + "a.75.75 0 0 1-.75-.75ZM8 6a1 1 0 1 1 0-2 1 1 0 0 1 0 2Z"
            case .tip:
                "M8 1.5c-2.363 0-4 1.69-4 3.75 0 .984.424 1.625.984 2.304l.214.253"
                    + "c.223.264.47.556.673.848.284.411.537.896.621 1.49a.75.75 0 0 1-1.484.211"
                    + "c-.04-.282-.163-.547-.37-.847a8.456 8.456 0 0 0-.542-.68"
                    + "c-.084-.1-.173-.205-.268-.32C3.201 7.75 2.5 6.766 2.5 5.25 2.5 2.31 4.863 0 8 0"
                    + "s5.5 2.31 5.5 5.25c0 1.516-.701 2.5-1.328 3.259-.095.115-.184.22-.268.319"
                    + "-.207.245-.383.453-.541.681-.208.3-.33.565-.37.847a.751.751 0 0 1-1.485-.212"
                    + "c.084-.593.337-1.078.621-1.489.203-.292.45-.584.673-.848"
                    + ".075-.088.147-.173.213-.253.561-.679.985-1.32.985-2.304 0-2.06-1.637-3.75-4-3.75Z"
                    + "M5.75 12h4.5a.75.75 0 0 1 0 1.5h-4.5a.75.75 0 0 1 0-1.5Z"
                    + "M6 15.25a.75.75 0 0 1 .75-.75h2.5a.75.75 0 0 1 0 1.5h-2.5"
                    + "a.75.75 0 0 1-.75-.75Z"
            case .important:
                "M0 1.75C0 .784.784 0 1.75 0h12.5C15.216 0 16 .784 16 1.75v9.5"
                    + "A1.75 1.75 0 0 1 14.25 13H8.06l-2.573 2.573A1.458 1.458 0 0 1 3 14.543V13"
                    + "H1.75A1.75 1.75 0 0 1 0 11.25Z"
                    + "m1.75-.25a.25.25 0 0 0-.25.25v9.5c0 .138.112.25.25.25h2a.75.75 0 0 1 .75.75v2.19"
                    + "l2.72-2.72a.749.749 0 0 1 .53-.22h6.5a.25.25 0 0 0 .25-.25v-9.5"
                    + "a.25.25 0 0 0-.25-.25Z"
                    + "m7 2.25v2.5a.75.75 0 0 1-1.5 0v-2.5a.75.75 0 0 1 1.5 0Z"
                    + "M9 9a1 1 0 1 1-2 0 1 1 0 0 1 2 0Z"
            case .warning:
                "M6.457 1.047c.659-1.234 2.427-1.234 3.086 0l6.082 11.378A1.75 1.75 0 0 1 14.082 15"
                    + "H1.918a1.75 1.75 0 0 1-1.543-2.575Z"
                    + "m1.763.707a.25.25 0 0 0-.44 0L1.698 13.132a.25.25 0 0 0 .22.368h12.164"
                    + "a.25.25 0 0 0 .22-.368Z"
                    + "m.53 3.996v2.5a.75.75 0 0 1-1.5 0v-2.5a.75.75 0 0 1 1.5 0Z"
                    + "M9 11a1 1 0 1 1-2 0 1 1 0 0 1 2 0Z"
            case .caution:
                "M4.47.22A.749.749 0 0 1 5 0h6c.199 0 .389.079.53.22l4.25 4.25"
                    + "c.141.14.22.331.22.53v6a.749.749 0 0 1-.22.53l-4.25 4.25"
                    + "A.749.749 0 0 1 11 16H5a.749.749 0 0 1-.53-.22L.22 11.53"
                    + "A.749.749 0 0 1 0 11V5c0-.199.079-.389.22-.53Z"
                    + "m.84 1.28L1.5 5.31v5.38l3.81 3.81h5.38l3.81-3.81V5.31L10.69 1.5Z"
                    + "M8 4a.75.75 0 0 1 .75.75v3.5a.75.75 0 0 1-1.5 0v-3.5"
                    + "A.75.75 0 0 1 8 4Z"
                    + "m0 8a1 1 0 1 1 0-2 1 1 0 0 1 0 2Z"
            }
        }
    }
}
