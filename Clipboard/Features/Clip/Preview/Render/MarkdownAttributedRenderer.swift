//
//  MarkdownAttributedRenderer.swift
//  Clipboard
//
//  基于 apple/swift-markdown 解析，将 markdown 渲染为 NSAttributedString。
//  样式全部使用动态系统颜色，自动适配深浅色。
//

import AppKit
import Markdown

struct MarkdownAttributedRenderer: MarkupVisitor {
    typealias Result = NSAttributedString

    // MARK: - 样式参数

    let baseFontSize = NSFont.systemFontSize
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
            .backgroundColor: NSColor.quaternaryLabelColor
        ])
    }

    mutating func visitLink(_ link: Link) -> NSAttributedString {
        let result = inlineChildren(of: link)
        if let destination = link.destination, let url = URL(string: destination) {
            result.addAttributes([
                .link: url,
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
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
            result.addAttribute(
                .markdownImageSource,
                value: source,
                range: NSRange(location: 0, length: result.length)
            )
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
            .paragraphStyle: style
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
                .paragraphStyle: style
            ]
        )
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

    // MARK: - 辅助

    func baseAttributes() -> [NSAttributedString.Key: Any] {
        [.font: bodyFont, .foregroundColor: NSColor.labelColor]
    }

    private func blockParagraphStyle() -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = blockSpacing
        style.lineSpacing = 1
        return style
    }

    func blockTerminator() -> NSAttributedString {
        NSAttributedString(string: "\n", attributes: baseAttributes())
    }

    /// 拼接行内子节点，结果可继续叠加样式
    mutating func inlineChildren(of markup: Markup) -> NSMutableAttributedString {
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
              (string.string as NSString).substring(from: string.length - 1) == "\n" {
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
