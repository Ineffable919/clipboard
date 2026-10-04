//
//  MarkdownFootnotes.swift
//  Clipboard
//
//  提取并渲染 Markdown 脚注。
//

import Foundation

// The extraction and token-restoration helpers form one parsing boundary.
nonisolated enum MarkdownFootnotes {
    struct Extraction {
        let markdown: String
        let definitions: [Definition]
        let references: [Reference]
    }

    struct Definition {
        let content: String
        let number: Int
    }

    struct Reference {
        let number: Int
        let ordinal: Int
    }

    private static let definitionRegex = regularExpression(
        #"^[ \t]{0,3}\[\^([^\]\n]+)\]:[ \t]*(.*)$"#
    )

    private static let referenceRegex = regularExpression(#"\[\^([^\]\n]+)\]"#)

    private static let codeFenceRegex = regularExpression(
        #"(?m)^(`{3,})[ \t]*([^\n`]*)\n([\s\S]*?)\n\1[ \t]*$"#
    )

    private static let inlineCodeRegex = regularExpression(
        #"(?<!`)(`+)(?!`)([^\n]*?)(?<!`)\1(?!`)"#
    )

    static func extract(from markdown: String) -> Extraction {
        guard markdown.contains("[^") else {
            return Extraction(markdown: markdown, definitions: [], references: [])
        }

        let split = splitDefinitions(from: markdown)
        var protected: [String] = []
        let withoutFences = replaceFullMatches(of: codeFenceRegex, in: split.markdown) { value in
            protected.append(value)
            return "ClipboardFootnoteProtect\(protected.count - 1)Token"
        }
        let withoutInlineCode = replaceFullMatches(of: inlineCodeRegex, in: withoutFences) { value in
            protected.append(value)
            return "ClipboardFootnoteProtect\(protected.count - 1)Token"
        }

        var orderedDefinitions: [(key: String, definition: Definition)] = []
        var referenceOrdinals: [Int: Int] = [:]
        var references: [Reference] = []

        let replaced = replaceReferences(in: withoutInlineCode) { label, original in
            let key = normalize(label)
            guard let content = split.definitions[key] else { return original }

            let definition: Definition
            if let existing = orderedDefinitions.first(where: { $0.key == key })?.definition {
                definition = existing
            } else {
                definition = Definition(content: content, number: orderedDefinitions.count + 1)
                orderedDefinitions.append((key, definition))
            }

            let ordinal = (referenceOrdinals[definition.number] ?? 0) + 1
            referenceOrdinals[definition.number] = ordinal
            references.append(Reference(number: definition.number, ordinal: ordinal))
            return "ClipboardFootnoteRef\(references.count - 1)Token"
        }

        return Extraction(
            markdown: restoreTokens(
                in: replaced,
                prefix: "ClipboardFootnoteProtect",
                replacements: protected
            ),
            definitions: orderedDefinitions.map(\.definition),
            references: references
        )
    }

    static func renderReferences(in html: String, extraction: Extraction) -> String {
        let replacements = extraction.references.map { reference in
            let referenceID = reference.ordinal == 1
                ? "fnref-\(reference.number)"
                : "fnref-\(reference.number)-\(reference.ordinal)"
            return "<sup class=\"footnote-ref\"><a id=\"\(referenceID)\" "
                + "href=\"#fn-\(reference.number)\">\(reference.number)</a></sup>"
        }
        return restoreTokens(
            in: html,
            prefix: "ClipboardFootnoteRef",
            replacements: replacements
        )
    }

    static func renderDefinitions(_ extraction: Extraction) -> String {
        guard !extraction.definitions.isEmpty else { return "" }

        let referencesByNumber = Dictionary(grouping: extraction.references, by: \.number)
        let items = extraction.definitions.map { definition in
            let backReferences = (referencesByNumber[definition.number] ?? []).map { reference in
                let referenceID = reference.ordinal == 1
                    ? "fnref-\(reference.number)"
                    : "fnref-\(reference.number)-\(reference.ordinal)"
                return "<a href=\"#\(referenceID)\" class=\"footnote-backref\">&#8617;</a>"
            }.joined(separator: " ")
            let content = appendBackReferences(
                backReferences,
                to: MarkdownSafeHTMLFormatter.format(definition.content)
            )
            return "<li id=\"fn-\(definition.number)\">\n\(content)</li>"
        }.joined(separator: "\n")

        return """

        <section class="footnotes" role="doc-endnotes">
        <hr />
        <ol>
        \(items)
        </ol>
        </section>
        """
    }
}

nonisolated extension MarkdownFootnotes {
    private static func splitDefinitions(from markdown: String) -> (
        markdown: String,
        definitions: [String: String]
    ) {
        let lines = markdown.components(separatedBy: "\n")
        var output: [String] = []
        var definitions: [String: String] = [:]
        var index = 0

        while index < lines.count {
            let line = lines[index]
            guard let match = firstMatch(of: definitionRegex, in: line) else {
                output.append(line)
                index += 1
                continue
            }

            let start = index
            let nsLine = line as NSString
            let label = nsLine.substring(with: match.range(at: 1))
            var content = [nsLine.substring(with: match.range(at: 2))]
            index += 1

            while index < lines.count {
                let continuation = lines[index]
                if continuation.trimmingCharacters(in: .whitespaces).isEmpty {
                    if index + 1 < lines.count, isIndentedContinuation(lines[index + 1]) {
                        content.append("")
                        index += 1
                        continue
                    }
                    break
                }
                guard isIndentedContinuation(continuation) else { break }
                content.append(stripContinuationIndent(continuation))
                index += 1
            }

            definitions[normalize(label)] = content.joined(separator: "\n")
            output.append(contentsOf: repeatElement("", count: index - start))
        }
        return (output.joined(separator: "\n"), definitions)
    }

    private static func appendBackReferences(_ backReferences: String, to html: String) -> String {
        guard !backReferences.isEmpty else { return html }
        let links = "<span class=\"footnote-backrefs\">\(backReferences)</span>"
        if let range = html.range(of: "</p>", options: .backwards) {
            var result = html
            result.replaceSubrange(range, with: " \(links)</p>")
            return result
        }
        return html + links
    }

    private static func replaceReferences(
        in source: String,
        transform: (String, String) -> String
    ) -> String {
        let nsSource = source as NSString
        let matches = referenceRegex.matches(
            in: source,
            range: NSRange(location: 0, length: nsSource.length)
        )
        guard !matches.isEmpty else { return source }

        var output = ""
        var cursor = 0
        for match in matches {
            output += nsSource.substring(with: NSRange(
                location: cursor,
                length: match.range.location - cursor
            ))
            output += transform(
                nsSource.substring(with: match.range(at: 1)),
                nsSource.substring(with: match.range)
            )
            cursor = match.range.location + match.range.length
        }
        output += nsSource.substring(from: cursor)
        return output
    }

    private static func replaceFullMatches(
        of regex: NSRegularExpression,
        in source: String,
        transform: (String) -> String
    ) -> String {
        let nsSource = source as NSString
        let matches = regex.matches(
            in: source,
            range: NSRange(location: 0, length: nsSource.length)
        )
        guard !matches.isEmpty else { return source }

        var output = ""
        var cursor = 0
        for match in matches {
            output += nsSource.substring(with: NSRange(
                location: cursor,
                length: match.range.location - cursor
            ))
            output += transform(nsSource.substring(with: match.range))
            cursor = match.range.location + match.range.length
        }
        output += nsSource.substring(from: cursor)
        return output
    }

    private static func restoreTokens(
        in source: String,
        prefix: String,
        replacements: [String]
    ) -> String {
        guard !replacements.isEmpty, source.contains(prefix) else { return source }

        var output = ""
        output.reserveCapacity(source.count)
        var cursor = source.startIndex

        while let tokenRange = source.range(of: prefix, range: cursor..<source.endIndex) {
            output += source[cursor..<tokenRange.lowerBound]

            var numberEnd = tokenRange.upperBound
            while numberEnd < source.endIndex, source[numberEnd].isNumber {
                numberEnd = source.index(after: numberEnd)
            }
            guard numberEnd > tokenRange.upperBound,
                  source[numberEnd...].hasPrefix("Token"),
                  let index = Int(source[tokenRange.upperBound..<numberEnd]),
                  replacements.indices.contains(index) else {
                output += prefix
                cursor = tokenRange.upperBound
                continue
            }

            output += replacements[index]
            cursor = source.index(numberEnd, offsetBy: "Token".count)
        }
        output += source[cursor...]
        return output
    }

    private static func firstMatch(
        of regex: NSRegularExpression,
        in source: String
    ) -> NSTextCheckingResult? {
        regex.firstMatch(
            in: source,
            range: NSRange(location: 0, length: (source as NSString).length)
        )
    }

    private static func normalize(_ label: String) -> String {
        label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isIndentedContinuation(_ line: String) -> Bool {
        line.hasPrefix("\t") || (line.count >= 4 && line.prefix(4).allSatisfy { $0 == " " })
    }

    private static func stripContinuationIndent(_ line: String) -> String {
        if line.hasPrefix("\t") {
            return String(line.dropFirst())
        }
        return String(line.dropFirst(4))
    }

    private static func regularExpression(_ pattern: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("Invalid Markdown footnote regular expression: \(error)")
        }
    }
}
