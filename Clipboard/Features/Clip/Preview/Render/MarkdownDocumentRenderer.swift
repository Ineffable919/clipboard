//
//  MarkdownDocumentRenderer.swift
//  Clipboard
//
//  组织 Frontmatter、脚注和正文的 Markdown 渲染流程。
//

import Foundation

nonisolated enum MarkdownDocumentRenderer {
    static func render(_ markdown: String) -> String {
        let frontmatter = MarkdownFrontmatter.split(markdown)
        let footnotes = MarkdownFootnotes.extract(from: frontmatter.body)
        let content = MarkdownSafeHTMLFormatter.format(footnotes.markdown)
        let body = MarkdownFootnotes.renderReferences(in: content, extraction: footnotes)
            + MarkdownFootnotes.renderDefinitions(footnotes)
        let rendered = renderFrontmatter(frontmatter.raw, format: frontmatter.format) + body

        guard MarkdownHTMLDirection.sourceMayNeedRTL(markdown) else { return rendered }
        return MarkdownHTMLDirection.inject(in: rendered)
    }

    private static func renderFrontmatter(
        _ raw: String?,
        format: MarkdownFrontmatter.Format?
    ) -> String {
        guard let raw, let format else { return "" }
        let entries = MarkdownFrontmatter.parse(raw, format: format)
        guard !entries.isEmpty else { return "" }

        let rows = entries.map { entry in
            let value: String
            if let items = entry.items {
                value = items.map {
                    "<span class=\"md-fm-pill\" dir=\"auto\">\(escape($0))</span>"
                }.joined()
            } else if entry.value.isEmpty {
                value = "<span class=\"md-fm-empty\" aria-hidden=\"true\"></span>"
            } else {
                value = escape(entry.value)
            }
            return "<tr><th scope=\"row\" dir=\"auto\">\(escape(entry.key))</th><td dir=\"auto\">\(value)</td></tr>"
        }.joined(separator: "\n")

        return """
        <section class="md-frontmatter">
        <table><tbody>
        \(rows)
        </tbody></table>
        </section>

        """
    }

    private static func escape(_ string: String) -> String {
        var output = ""
        output.reserveCapacity(string.count)
        for character in string {
            switch character {
            case "&": output += "&amp;"
            case "<": output += "&lt;"
            case ">": output += "&gt;"
            case "\"": output += "&quot;"
            default: output.append(character)
            }
        }
        return output
    }
}
