//
//  MarkdownAttributedRenderer.swift
//  Clipboard
//
//  基于 apple/swift-markdown 解析，将 markdown 渲染为 NSAttributedString。
//  样式全部使用动态系统颜色，自动适配深浅色。
//

import AppKit
import Markdown

enum MarkdownHTMLRenderer {
    static func htmlDocument(for markdown: String) -> String {
        let body = HTMLFormatter.format(markdown)
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data: file: http: https:; media-src data: file: http: https:; style-src 'unsafe-inline'; font-src data:; script-src 'none'; frame-src 'none'; object-src 'none'; connect-src 'none'; base-uri 'none'; form-action 'none'">
        <style>
        :root {
            color-scheme: light dark;
            --page: rgb(255, 255, 255);
            --text: rgb(31, 35, 40);
            --muted: rgb(89, 99, 110);
            --link: rgb(0, 97, 201);
            --border: rgba(31, 35, 40, 0.16);
            --soft-border: rgba(31, 35, 40, 0.10);
            --code-bg: rgba(175, 184, 193, 0.20);
            --pre-bg: rgb(246, 248, 250);
            --quote-bg: rgba(9, 105, 218, 0.05);
            --table-head: rgba(175, 184, 193, 0.18);
        }

        @media (prefers-color-scheme: dark) {
            :root {
                --page: rgb(30, 30, 30);
                --text: rgb(230, 237, 243);
                --muted: rgb(139, 148, 158);
                --link: rgb(88, 166, 255);
                --border: rgba(240, 246, 252, 0.18);
                --soft-border: rgba(240, 246, 252, 0.10);
                --code-bg: rgba(110, 118, 129, 0.36);
                --pre-bg: rgb(22, 27, 34);
                --quote-bg: rgba(88, 166, 255, 0.10);
                --table-head: rgba(110, 118, 129, 0.22);
            }
        }

        * {
            box-sizing: border-box;
        }

        html {
            background: var(--page);
            color: var(--text);
            font: -apple-system-body;
            overflow-wrap: anywhere;
        }

        body {
            margin: 0;
            padding: 12px 14px 14px;
            background: var(--page);
            color: var(--text);
            line-height: 1.48;
            -webkit-font-smoothing: antialiased;
        }

        body > :first-child {
            margin-top: 0;
        }

        body > :last-child {
            margin-bottom: 0;
        }

        h1, h2, h3, h4, h5, h6 {
            margin: 1.05em 0 0.45em;
            color: var(--text);
            font-weight: 650;
            line-height: 1.22;
        }

        h1 {
            padding-bottom: 0.28em;
            border-bottom: 1px solid var(--soft-border);
            font-size: 1.65em;
        }

        h2 {
            padding-bottom: 0.22em;
            border-bottom: 1px solid var(--soft-border);
            font-size: 1.38em;
        }

        h3 { font-size: 1.18em; }
        h4 { font-size: 1.05em; }
        h5, h6 {
            color: var(--muted);
            font-size: 1em;
        }

        p, blockquote, ul, ol, dl, table, pre {
            margin: 0.72em 0;
        }

        a {
            color: var(--link);
            text-decoration: none;
        }

        a:hover {
            text-decoration: underline;
        }

        strong {
            font-weight: 650;
        }

        code, pre {
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
            font-size: 0.92em;
        }

        code {
            padding: 0.13em 0.34em;
            border-radius: 5px;
            background: var(--code-bg);
        }

        pre {
            overflow: auto;
            padding: 12px;
            border: 1px solid var(--soft-border);
            border-radius: 8px;
            background: var(--pre-bg);
            line-height: 1.45;
        }

        pre code {
            display: block;
            padding: 0;
            border-radius: 0;
            background: transparent;
            white-space: pre;
            overflow-wrap: normal;
        }

        blockquote {
            margin-left: 0;
            padding: 8px 12px;
            border-left: 3px solid var(--link);
            border-radius: 0 8px 8px 0;
            background: var(--quote-bg);
            color: var(--muted);
        }

        blockquote > :first-child {
            margin-top: 0;
        }

        blockquote > :last-child {
            margin-bottom: 0;
        }

        ul, ol {
            padding-left: 1.55em;
        }

        li {
            margin: 0.22em 0;
        }

        li > p {
            margin: 0.28em 0;
        }

        hr {
            height: 1px;
            margin: 1.05em 0;
            border: 0;
            background: var(--border);
        }

        table {
            width: 100%;
            border-collapse: collapse;
            display: block;
            overflow-x: auto;
            border-spacing: 0;
        }

        th, td {
            padding: 7px 9px;
            border: 1px solid var(--border);
            vertical-align: top;
        }

        th {
            background: var(--table-head);
            font-weight: 650;
        }

        img, video {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
        }

        img {
            display: block;
            margin: 0.8em 0;
        }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }
}

struct MarkdownAttributedRenderer: MarkupVisitor {
    typealias Result = NSAttributedString

    // MARK: - 样式参数

    private let baseFontSize = NSFont.systemFontSize
    private let blockSpacing = NSFont.systemFontSize * 0.7
    private let listIndent: CGFloat = 22

    private var bodyFont: NSFont {
        .systemFont(ofSize: baseFontSize)
    }

    private var codeFont: NSFont {
        .monospacedSystemFont(ofSize: baseFontSize - 1, weight: .regular)
    }

    private var listLevel = 0

    // MARK: - 入口

    static func renderSync(_ markdown: String) -> NSAttributedString {
        var renderer = MarkdownAttributedRenderer()
        let document = Document(parsing: markdown)
        let result = NSMutableAttributedString(attributedString: renderer.visit(document))
        trimTrailingNewlines(result)
        return result
    }

    @MainActor
    static func render(_ markdown: String) async -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: renderSync(markdown))
        await loadImages(into: result)
        return result
    }

    // MARK: - 图片加载

    @MainActor
    private static func loadImages(into result: NSMutableAttributedString) async {
        var imageRanges: [(range: NSRange, source: String)] = []
        result.enumerateAttribute(.markdownImageSource, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            if let source = value as? String {
                imageRanges.append((range, source))
            }
        }
        // 逆序替换以保证 range 不偏移
        for item in imageRanges.reversed() {
            guard let url = URL(string: item.source) else { continue }
            let data: Data?
            if url.isFileURL {
                data = await Task.detached { try? Data(contentsOf: url) }.value
            } else if url.scheme == "https" || url.scheme == "http" {
                data = try? await URLSession.shared.data(from: url).0
            } else {
                continue
            }
            guard let data, let image = NSImage(data: data) else { continue }
            let attachment = NSTextAttachment()
            attachment.image = image
            let maxW: CGFloat = 400
            let w = min(image.size.width, maxW)
            let h = image.size.height * (w / image.size.width)
            attachment.bounds = CGRect(x: 0, y: 0, width: w, height: h)
            result.replaceCharacters(in: item.range, with: NSAttributedString(attachment: attachment))
        }
    }

    private static func trimTrailingNewlines(_ result: NSMutableAttributedString) {
        while result.length > 0,
              (result.string as NSString).substring(from: result.length - 1) == "\n"
        {
            result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
        }
    }

    // MARK: - 默认遍历

    mutating func defaultVisit(_ markup: Markup) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in markup.children {
            result.append(visit(child))
        }
        return result
    }

    // MARK: - 行内元素

    mutating func visitText(_ text: Text) -> NSAttributedString {
        NSAttributedString(string: text.string, attributes: baseAttributes())
    }

    mutating func visitSoftBreak(_: SoftBreak) -> NSAttributedString {
        NSAttributedString(string: " ", attributes: baseAttributes())
    }

    mutating func visitLineBreak(_: LineBreak) -> NSAttributedString {
        NSAttributedString(string: "\n", attributes: baseAttributes())
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> NSAttributedString {
        applyTrait(.italicFontMask, to: emphasis)
    }

    mutating func visitStrong(_ strong: Strong) -> NSAttributedString {
        applyTrait(.boldFontMask, to: strong)
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> NSAttributedString {
        let result = inlineChildren(of: strikethrough)
        result.addAttribute(
            .strikethroughStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: NSRange(location: 0, length: result.length)
        )
        return result
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> NSAttributedString {
        NSAttributedString(string: inlineCode.code, attributes: [
            .font: codeFont,
            .foregroundColor: NSColor.labelColor,
            .backgroundColor: NSColor.quaternaryLabelColor,
        ])
    }

    mutating func visitLink(_ link: Link) -> NSAttributedString {
        let result = inlineChildren(of: link)
        if let destination = link.destination, let url = URL(string: destination) {
            result.addAttributes([
                .link: url,
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ], range: NSRange(location: 0, length: result.length))
        }
        return result
    }

    mutating func visitImage(_ image: Image) -> NSAttributedString {
        let alt = image.plainText.isEmpty ? (image.source ?? "image") : image.plainText
        let config = NSImage.SymbolConfiguration(pointSize: baseFontSize * 2.5, weight: .regular)
        let placeholder = NSImage(systemSymbolName: "photo.badge.arrow.down.fill", accessibilityDescription: alt)?
            .withSymbolConfiguration(config) ?? NSImage()
        let attachment = NSTextAttachment()
        attachment.image = placeholder
        let result = NSMutableAttributedString(attachment: attachment)
        if let source = image.source, !source.isEmpty {
            result.addAttribute(.markdownImageSource, value: source, range: NSRange(location: 0, length: result.length))
        }
        result.append(blockTerminator())
        return result
    }

    // MARK: - 块级元素

    mutating func visitParagraph(_ paragraph: Paragraph) -> NSAttributedString {
        let result = inlineChildren(of: paragraph)
        result.applyParagraphStyleIfAbsent(blockParagraphStyle())
        result.append(blockTerminator())
        return result
    }

    mutating func visitHeading(_ heading: Heading) -> NSAttributedString {
        let sizeBump: CGFloat = [10, 6, 4, 2, 1, 0][min(max(heading.level - 1, 0), 5)]
        let font = NSFont.systemFont(ofSize: baseFontSize + sizeBump, weight: .bold)

        let result = inlineChildren(of: heading)
        result.addAttribute(
            .font,
            value: font,
            range: NSRange(location: 0, length: result.length)
        )
        let style = blockParagraphStyle()
        style.paragraphSpacingBefore = blockSpacing * 0.6
        result.applyParagraphStyleIfAbsent(style)
        result.append(blockTerminator())
        return result
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> NSAttributedString {
        var code = codeBlock.code
        if code.hasSuffix("\n") {
            code.removeLast()
        }

        let style = blockParagraphStyle()
        style.firstLineHeadIndent = Const.space8
        style.headIndent = Const.space8

        let result = NSMutableAttributedString(string: code, attributes: [
            .font: codeFont,
            .foregroundColor: NSColor.labelColor,
            .backgroundColor: NSColor.quaternaryLabelColor,
            .paragraphStyle: style,
        ])
        result.append(blockTerminator())
        return result
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> NSAttributedString {
        let inner = NSMutableAttributedString()
        for child in blockQuote.children {
            inner.append(visit(child))
        }
        let style = blockParagraphStyle()
        style.firstLineHeadIndent = listIndent
        style.headIndent = listIndent
        inner.applyParagraphStyleIfAbsent(style)
        inner.addAttribute(
            .foregroundColor,
            value: NSColor.secondaryLabelColor,
            range: NSRange(location: 0, length: inner.length)
        )
        return inner
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> NSAttributedString {
        renderList(unorderedList, ordered: false, start: 1)
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> NSAttributedString {
        renderList(orderedList, ordered: true, start: Int(orderedList.startIndex))
    }

    mutating func visitThematicBreak(_: ThematicBreak) -> NSAttributedString {
        let style = blockParagraphStyle()
        let result = NSMutableAttributedString(
            string: "⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯",
            attributes: [
                .font: bodyFont,
                .foregroundColor: NSColor.tertiaryLabelColor,
                .paragraphStyle: style,
            ]
        )
        result.append(blockTerminator())
        return result
    }

    mutating func visitTable(_ table: Markdown.Table) -> NSAttributedString {
        let textTable = NSTextTable()
        let columnCount = table.maxColumnCount
        textTable.numberOfColumns = columnCount

        let result = NSMutableAttributedString()
        var rowIndex = 0

        appendTableRow(
            cells: Array(table.head.cells),
            row: rowIndex,
            isHeader: true,
            table: textTable,
            columnCount: columnCount,
            into: result
        )
        rowIndex += 1

        for row in table.body.rows {
            appendTableRow(
                cells: Array(row.cells),
                row: rowIndex,
                isHeader: false,
                table: textTable,
                columnCount: columnCount,
                into: result
            )
            rowIndex += 1
        }

        result.append(blockTerminator())
        return result
    }

    // MARK: - 列表渲染

    private mutating func renderList(
        _ list: Markup,
        ordered: Bool,
        start: Int
    ) -> NSAttributedString {
        listLevel += 1
        defer { listLevel -= 1 }

        let result = NSMutableAttributedString()
        var index = start

        for case let item as ListItem in list.children {
            let marker = ordered ? "\(index). " : "• "
            index += 1

            let itemContent = NSMutableAttributedString()
            for child in item.children {
                itemContent.append(visit(child))
            }
            // 去掉条目末尾的块分隔换行，列表项之间只留单个换行
            trimTrailingNewline(itemContent)

            let line = NSMutableAttributedString(
                string: marker,
                attributes: baseAttributes()
            )
            line.append(itemContent)

            let indent = listIndent * CGFloat(listLevel)
            let style = blockParagraphStyle()
            style.paragraphSpacing = 2
            style.firstLineHeadIndent = indent - listIndent + Const.space8
            style.headIndent = indent
            line.applyParagraphStyleIfAbsent(style)

            line.append(NSAttributedString(string: "\n", attributes: baseAttributes()))
            result.append(line)
        }
        return result
    }

    // MARK: - 表格渲染

    private mutating func appendTableRow(
        cells: [Markdown.Table.Cell],
        row: Int,
        isHeader: Bool,
        table: NSTextTable,
        columnCount: Int,
        into result: NSMutableAttributedString
    ) {
        for column in 0 ..< columnCount {
            let block = NSTextTableBlock(
                table: table,
                startingRow: row,
                rowSpan: 1,
                startingColumn: column,
                columnSpan: 1
            )
            block.setBorderColor(.separatorColor)
            block.setWidth(1, type: .absoluteValueType, for: .border)
            block.setWidth(Const.space6, type: .absoluteValueType, for: .padding)
            if isHeader {
                block.backgroundColor = .quaternaryLabelColor
            }

            let style = NSMutableParagraphStyle()
            style.textBlocks = [block]

            let cellContent: NSMutableAttributedString = if column < cells.count {
                inlineChildren(of: cells[column])
            } else {
                NSMutableAttributedString()
            }
            if cellContent.length == 0 {
                cellContent.append(NSAttributedString(string: " ", attributes: baseAttributes()))
            }
            if isHeader {
                cellContent.addAttribute(
                    .font,
                    value: NSFont.systemFont(ofSize: baseFontSize, weight: .semibold),
                    range: NSRange(location: 0, length: cellContent.length)
                )
            }
            cellContent.addAttribute(
                .paragraphStyle,
                value: style,
                range: NSRange(location: 0, length: cellContent.length)
            )
            cellContent.append(NSAttributedString(string: "\n"))
            result.append(cellContent)
        }
    }

    // MARK: - 辅助

    private func baseAttributes() -> [NSAttributedString.Key: Any] {
        [.font: bodyFont, .foregroundColor: NSColor.labelColor]
    }

    private func blockParagraphStyle() -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = blockSpacing
        style.lineSpacing = 1
        return style
    }

    private func blockTerminator() -> NSAttributedString {
        NSAttributedString(string: "\n", attributes: baseAttributes())
    }

    /// 拼接行内子节点，结果可继续叠加样式
    private mutating func inlineChildren(of markup: Markup) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for child in markup.children {
            result.append(visit(child))
        }
        return result
    }

    /// 对子节点应用字体 trait（粗体/斜体），保留子节点已有字体
    private mutating func applyTrait(
        _ trait: NSFontTraitMask,
        to markup: Markup
    ) -> NSMutableAttributedString {
        let result = inlineChildren(of: markup)
        let fullRange = NSRange(location: 0, length: result.length)
        result.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            let base = (value as? NSFont) ?? bodyFont
            let converted = NSFontManager.shared.convert(base, toHaveTrait: trait)
            result.addAttribute(.font, value: converted, range: range)
        }
        return result
    }

    private func trimTrailingNewline(_ string: NSMutableAttributedString) {
        while string.length > 0,
              (string.string as NSString).substring(from: string.length - 1) == "\n"
        {
            string.deleteCharacters(in: NSRange(location: string.length - 1, length: 1))
        }
    }
}

// MARK: - 自定义 AttributedString Key

extension NSAttributedString.Key {
    static let markdownImageSource = NSAttributedString.Key("markdownImageSource")
}

// MARK: - 段落样式辅助

private extension NSMutableAttributedString {
    /// 仅在尚未设置段落样式的区间应用样式，避免覆盖嵌套块（如列表内的子列表）已有样式
    func applyParagraphStyleIfAbsent(_ style: NSParagraphStyle) {
        let fullRange = NSRange(location: 0, length: length)
        enumerateAttribute(.paragraphStyle, in: fullRange) { value, range, _ in
            if value == nil {
                addAttribute(.paragraphStyle, value: style, range: range)
            }
        }
    }
}
