//
//  JSONTransformer.swift
//  Clipboard
//
//  JSON 全文转换。所有入口均为纯计算，可安全放到后台任务执行。
//

import Foundation

enum JSONTransformer {
    nonisolated static func looksLikeJSON(_ text: String) -> Bool {
        guard let first = text.utf8.first(where: { !isWhitespace($0) }) else {
            return false
        }
        return first == Byte.leftBrace || first == Byte.leftBracket
    }

    nonisolated static func isValid(_ text: String) -> Bool {
        do {
            var source = text
            try source.withUTF8 { bytes in
                var parser = Validator(bytes: bytes)
                try parser.parseDocument()
            }
            return true
        } catch {
            return false
        }
    }

    nonisolated static func transform(
        _ text: String,
        action: JSONToolAction
    ) throws -> String {
        try checkCancellation()

        return switch action {
        case let .format(indentation):
            try format(text, indentation: indentation)
        case .compact:
            try compact(text)
        case .addEscapes:
            try addEscapes(text)
        case .removeEscapes:
            try removeEscapes(text)
        case .encodeUnicode:
            try encodeUnicode(text)
        case .decodeUnicode:
            try decodeUnicode(text)
        case let .sortKeys(ascending, indentation):
            try rewriteObjects(
                text,
                indentation: indentation,
                ascending: ascending,
                naming: nil
            )
        case let .renameKeys(naming, indentation):
            try rewriteObjects(
                text,
                indentation: indentation,
                ascending: nil,
                naming: naming
            )
        }
    }

    // MARK: - Whitespace

    nonisolated static func format(
        _ text: String,
        indentation: JSONIndentation
    ) throws -> String {
        try rewriteWhitespace(text, indentation: indentation.rawValue)
    }

    nonisolated static func compact(_ text: String) throws -> String {
        try rewriteWhitespace(text, indentation: nil)
    }

    nonisolated static func rewriteWhitespace(
        _ text: String,
        indentation: Int?
    ) throws -> String {
        var source = text
        return try source.withUTF8 { bytes in
            var parser = Validator(bytes: bytes, indentation: indentation, rewritesWhitespace: true)
            parser.output.reserveCapacity(bytes.count)
            try parser.parseDocument()
            return decode(parser.output)
        }
    }

    // MARK: - Object Rewriting

    nonisolated static func rewriteObjects(
        _ text: String,
        indentation: JSONIndentation,
        ascending: Bool?,
        naming: JSONKeyNaming?
    ) throws -> String {
        let bytes = Array(text.utf8)
        var parser = TreeParser(bytes: bytes)
        let root = try parser.parseDocument()
        var writer = TreeWriter(
            source: bytes,
            indentation: indentation.rawValue,
            ascending: ascending,
            naming: naming
        )
        try writer.write(root)
        return decode(writer.output)
    }

    indirect nonisolated enum Node {
        case object([Member])
        case array([Node])
        case scalar(Range<Int>)
    }

    nonisolated struct Member {
        let key: String
        let rawKeyRange: Range<Int>
        let value: Node
    }

}
