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
            var parser = Validator(bytes: Array(text.utf8))
            try parser.parseDocument()
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

    private nonisolated static func format(
        _ text: String,
        indentation: JSONIndentation
    ) throws -> String {
        let bytes = Array(text.utf8)
        var parser = Validator(bytes: bytes)
        try parser.parseDocument()
        return try rewriteWhitespace(bytes, indentation: indentation.rawValue)
    }

    private nonisolated static func compact(_ text: String) throws -> String {
        let bytes = Array(text.utf8)
        var parser = Validator(bytes: bytes)
        try parser.parseDocument()
        return try rewriteWhitespace(bytes, indentation: nil)
    }

    private nonisolated static func rewriteWhitespace(
        _ bytes: [UInt8],
        indentation: Int?
    ) throws -> String {
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)

        var index = 0
        var depth = 0
        var isInsideString = false
        var isEscaped = false
        var previousToken: UInt8?

        func appendNewline(depth: Int, to output: inout [UInt8]) {
            output.append(Byte.newline)
            guard let indentation, indentation > 0 else { return }
            output.append(contentsOf: repeatElement(
                Byte.space,
                count: depth * indentation
            ))
        }

        while index < bytes.count {
            if index.isMultiple(of: 16384) {
                try checkCancellation()
            }
            let byte = bytes[index]

            if isInsideString {
                output.append(byte)
                if isEscaped {
                    isEscaped = false
                } else if byte == Byte.backslash {
                    isEscaped = true
                } else if byte == Byte.quote {
                    isInsideString = false
                    previousToken = byte
                }
                index += 1
                continue
            }

            if byte == Byte.quote {
                isInsideString = true
                output.append(byte)
                index += 1
                continue
            }

            if isWhitespace(byte) {
                index += 1
                continue
            }

            switch byte {
            case Byte.leftBrace, Byte.leftBracket:
                output.append(byte)
                depth += 1
                if indentation != nil,
                   nextToken(in: bytes, after: index) != matchingClose(for: byte)
                {
                    appendNewline(depth: depth, to: &output)
                }
            case Byte.rightBrace, Byte.rightBracket:
                depth = max(0, depth - 1)
                if indentation != nil,
                   previousToken != matchingOpen(for: byte)
                {
                    appendNewline(depth: depth, to: &output)
                }
                output.append(byte)
            case Byte.comma:
                output.append(byte)
                if indentation != nil {
                    appendNewline(depth: depth, to: &output)
                }
            case Byte.colon:
                output.append(byte)
                if indentation != nil {
                    output.append(Byte.space)
                }
            default:
                output.append(byte)
            }

            previousToken = byte
            index += 1
        }

        return String(decoding: output, as: UTF8.self)
    }

    // MARK: - Escaping

    private nonisolated static func addEscapes(_ text: String) throws -> String {
        var output: [UInt8] = []
        output.reserveCapacity(text.utf8.count + text.utf8.count / 8)

        for (index, byte) in text.utf8.enumerated() {
            if index.isMultiple(of: 16384) {
                try checkCancellation()
            }
            switch byte {
            case Byte.quote:
                output.append(contentsOf: [Byte.backslash, Byte.quote])
            case Byte.backslash:
                output.append(contentsOf: [Byte.backslash, Byte.backslash])
            case Byte.newline:
                output.append(contentsOf: [Byte.backslash, Byte.lowercaseN])
            case Byte.carriageReturn:
                output.append(contentsOf: [Byte.backslash, Byte.lowercaseR])
            case Byte.tab:
                output.append(contentsOf: [Byte.backslash, Byte.lowercaseT])
            default:
                output.append(byte)
            }
        }

        return String(decoding: output, as: UTF8.self)
    }

    private nonisolated static func removeEscapes(_ text: String) throws -> String {
        let bytes = Array(text.utf8)
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var index = 0

        while index < bytes.count {
            if index.isMultiple(of: 16384) {
                try checkCancellation()
            }
            guard bytes[index] == Byte.backslash, index + 1 < bytes.count else {
                output.append(bytes[index])
                index += 1
                continue
            }

            switch bytes[index + 1] {
            case Byte.quote, Byte.backslash, Byte.slash:
                output.append(bytes[index + 1])
                index += 2
            case Byte.lowercaseB:
                output.append(Byte.backspace)
                index += 2
            case Byte.lowercaseF:
                output.append(Byte.formFeed)
                index += 2
            case Byte.lowercaseN:
                output.append(Byte.newline)
                index += 2
            case Byte.lowercaseR:
                output.append(Byte.carriageReturn)
                index += 2
            case Byte.lowercaseT:
                output.append(Byte.tab)
                index += 2
            case Byte.lowercaseU:
                if let decoded = decodeUnicodeEscape(bytes, at: index) {
                    appendUTF8(decoded.scalar, to: &output)
                    index = decoded.nextIndex
                } else {
                    output.append(bytes[index])
                    index += 1
                }
            default:
                output.append(bytes[index])
                index += 1
            }
        }

        return String(decoding: output, as: UTF8.self)
    }

    private nonisolated static func encodeUnicode(_ text: String) throws -> String {
        var output: [UInt8] = []
        output.reserveCapacity(text.utf8.count + text.utf8.count / 2)

        for (index, scalar) in text.unicodeScalars.enumerated() {
            if index.isMultiple(of: 16384) {
                try checkCancellation()
            }
            let value = scalar.value
            guard value > 0x7F else {
                output.append(UInt8(value))
                continue
            }

            if value <= 0xFFFF {
                appendUnicodeEscape(UInt16(value), to: &output)
            } else {
                let adjusted = value - 0x10000
                let high = UInt16(0xD800 + (adjusted >> 10))
                let low = UInt16(0xDC00 + (adjusted & 0x3FF))
                appendUnicodeEscape(high, to: &output)
                appendUnicodeEscape(low, to: &output)
            }
        }

        return String(decoding: output, as: UTF8.self)
    }

    private nonisolated static func decodeUnicode(_ text: String) throws -> String {
        let bytes = Array(text.utf8)
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var index = 0
        var precedingBackslashes = 0

        while index < bytes.count {
            if index.isMultiple(of: 16384) {
                try checkCancellation()
            }
            let byte = bytes[index]
            if byte == Byte.backslash {
                if precedingBackslashes.isMultiple(of: 2),
                   let decoded = decodeUnicodeEscape(bytes, at: index)
                {
                    appendUTF8(decoded.scalar, to: &output)
                    index = decoded.nextIndex
                    precedingBackslashes = 0
                    continue
                }

                output.append(byte)
                precedingBackslashes += 1
                index += 1
                continue
            }

            output.append(byte)
            precedingBackslashes = 0
            index += 1
        }

        return String(decoding: output, as: UTF8.self)
    }

    // MARK: - Object Rewriting

    private nonisolated static func rewriteObjects(
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
        return String(decoding: writer.output, as: UTF8.self)
    }

    private indirect nonisolated enum Node {
        case object([Member])
        case array([Node])
        case scalar(Range<Int>)
    }

    private nonisolated struct Member {
        let key: String
        let rawKeyRange: Range<Int>
        let value: Node
    }

    private nonisolated struct TreeParser {
        let bytes: [UInt8]
        var index = 0

        mutating func parseDocument() throws -> Node {
            skipWhitespace()
            let node = try parseValue(depth: 0)
            skipWhitespace()
            guard index == bytes.count else { throw JSONTransformError.invalidJSON }
            return node
        }

        private mutating func parseValue(depth: Int) throws -> Node {
            try checkpoint()
            guard index < bytes.count, depth <= 1024 else {
                throw JSONTransformError.invalidJSON
            }

            return switch bytes[index] {
            case Byte.leftBrace: try parseObject(depth: depth)
            case Byte.leftBracket: try parseArray(depth: depth)
            case Byte.quote:
                try .scalar(parseRawString())
            case Byte.lowercaseT:
                try .scalar(parseLiteral(Array("true".utf8)))
            case Byte.lowercaseF:
                try .scalar(parseLiteral(Array("false".utf8)))
            case Byte.lowercaseN:
                try .scalar(parseLiteral(Array("null".utf8)))
            default:
                try .scalar(parseNumber())
            }
        }

        private mutating func parseObject(depth: Int) throws -> Node {
            index += 1
            skipWhitespace()
            var members: [Member] = []

            if consume(Byte.rightBrace) {
                return .object(members)
            }

            while true {
                guard index < bytes.count, bytes[index] == Byte.quote else {
                    throw JSONTransformError.invalidJSON
                }
                let keyStart = index
                let key = try parseDecodedString()
                let keyRange = keyStart ..< index
                skipWhitespace()
                try require(Byte.colon)
                skipWhitespace()
                let value = try parseValue(depth: depth + 1)
                members.append(Member(key: key, rawKeyRange: keyRange, value: value))
                skipWhitespace()

                if consume(Byte.rightBrace) {
                    return .object(members)
                }
                try require(Byte.comma)
                skipWhitespace()
            }
        }

        private mutating func parseArray(depth: Int) throws -> Node {
            index += 1
            skipWhitespace()
            var values: [Node] = []

            if consume(Byte.rightBracket) {
                return .array(values)
            }

            while true {
                try values.append(parseValue(depth: depth + 1))
                skipWhitespace()
                if consume(Byte.rightBracket) {
                    return .array(values)
                }
                try require(Byte.comma)
                skipWhitespace()
            }
        }

        private mutating func parseRawString() throws -> Range<Int> {
            let start = index
            _ = try parseString(shouldDecode: false)
            return start ..< index
        }

        private mutating func parseDecodedString() throws -> String {
            guard let decoded = try parseString(shouldDecode: true) else {
                throw JSONTransformError.invalidJSON
            }
            return decoded
        }

        private mutating func parseString(shouldDecode: Bool) throws -> String? {
            try require(Byte.quote)
            var decoded: [UInt8] = []

            while index < bytes.count {
                try checkpoint()
                let byte = bytes[index]
                index += 1

                if byte == Byte.quote {
                    guard shouldDecode else { return nil }
                    guard let string = String(bytes: decoded, encoding: .utf8) else {
                        throw JSONTransformError.invalidJSON
                    }
                    return string
                }

                guard byte >= 0x20 else { throw JSONTransformError.invalidJSON }

                guard byte == Byte.backslash else {
                    if shouldDecode {
                        decoded.append(byte)
                    }
                    continue
                }

                guard index < bytes.count else { throw JSONTransformError.invalidJSON }
                let escaped = bytes[index]
                index += 1

                switch escaped {
                case Byte.quote, Byte.backslash, Byte.slash:
                    if shouldDecode {
                        decoded.append(escaped)
                    }
                case Byte.lowercaseB:
                    if shouldDecode {
                        decoded.append(Byte.backspace)
                    }
                case Byte.lowercaseF:
                    if shouldDecode {
                        decoded.append(Byte.formFeed)
                    }
                case Byte.lowercaseN:
                    if shouldDecode {
                        decoded.append(Byte.newline)
                    }
                case Byte.lowercaseR:
                    if shouldDecode {
                        decoded.append(Byte.carriageReturn)
                    }
                case Byte.lowercaseT:
                    if shouldDecode {
                        decoded.append(Byte.tab)
                    }
                case Byte.lowercaseU:
                    let escapeStart = index - 2
                    guard let result = JSONTransformer.decodeUnicodeEscape(
                        bytes,
                        at: escapeStart
                    ) else {
                        throw JSONTransformError.invalidJSON
                    }
                    if shouldDecode {
                        JSONTransformer.appendUTF8(result.scalar, to: &decoded)
                    }
                    index = result.nextIndex
                default:
                    throw JSONTransformError.invalidJSON
                }
            }

            throw JSONTransformError.invalidJSON
        }

        private mutating func parseLiteral(_ literal: [UInt8]) throws -> Range<Int> {
            let start = index
            guard bytes[index...].starts(with: literal) else {
                throw JSONTransformError.invalidJSON
            }
            index += literal.count
            return start ..< index
        }

        private mutating func parseNumber() throws -> Range<Int> {
            let start = index
            if consume(Byte.minus), index >= bytes.count {
                throw JSONTransformError.invalidJSON
            }

            if consume(Byte.zero) {
                if index < bytes.count, isDigit(bytes[index]) {
                    throw JSONTransformError.invalidJSON
                }
            } else {
                guard index < bytes.count, isOneToNine(bytes[index]) else {
                    throw JSONTransformError.invalidJSON
                }
                index += 1
                while index < bytes.count, isDigit(bytes[index]) {
                    index += 1
                }
            }

            if consume(Byte.period) {
                guard index < bytes.count, isDigit(bytes[index]) else {
                    throw JSONTransformError.invalidJSON
                }
                while index < bytes.count, isDigit(bytes[index]) {
                    index += 1
                }
            }

            if index < bytes.count,
               bytes[index] == Byte.lowercaseE || bytes[index] == Byte.uppercaseE
            {
                index += 1
                if index < bytes.count,
                   bytes[index] == Byte.plus || bytes[index] == Byte.minus
                {
                    index += 1
                }
                guard index < bytes.count, isDigit(bytes[index]) else {
                    throw JSONTransformError.invalidJSON
                }
                while index < bytes.count, isDigit(bytes[index]) {
                    index += 1
                }
            }

            return start ..< index
        }

        private mutating func require(_ byte: UInt8) throws {
            guard consume(byte) else { throw JSONTransformError.invalidJSON }
        }

        private mutating func consume(_ byte: UInt8) -> Bool {
            guard index < bytes.count, bytes[index] == byte else { return false }
            index += 1
            return true
        }

        private mutating func skipWhitespace() {
            while index < bytes.count, JSONTransformer.isWhitespace(bytes[index]) {
                index += 1
            }
        }

        private func checkpoint() throws {
            if index.isMultiple(of: 16384) {
                try JSONTransformer.checkCancellation()
            }
        }
    }

    private nonisolated struct TreeWriter {
        let source: [UInt8]
        let indentation: Int
        let ascending: Bool?
        let naming: JSONKeyNaming?
        var output: [UInt8] = []

        init(
            source: [UInt8],
            indentation: Int,
            ascending: Bool?,
            naming: JSONKeyNaming?
        ) {
            self.source = source
            self.indentation = indentation
            self.ascending = ascending
            self.naming = naming
            output.reserveCapacity(source.count + source.count / 8)
        }

        mutating func write(_ node: Node, depth: Int = 0) throws {
            try JSONTransformer.checkCancellation()

            switch node {
            case let .scalar(range):
                output.append(contentsOf: source[range])
            case let .array(values):
                try writeArray(values, depth: depth)
            case let .object(members):
                try writeObject(members, depth: depth)
            }
        }

        private mutating func writeArray(_ values: [Node], depth: Int) throws {
            output.append(Byte.leftBracket)
            guard !values.isEmpty else {
                output.append(Byte.rightBracket)
                return
            }

            appendNewline(depth: depth + 1)
            for (index, value) in values.enumerated() {
                try write(value, depth: depth + 1)
                if index < values.count - 1 {
                    output.append(Byte.comma)
                    appendNewline(depth: depth + 1)
                }
            }
            appendNewline(depth: depth)
            output.append(Byte.rightBracket)
        }

        private mutating func writeObject(_ members: [Member], depth: Int) throws {
            let prepared = try prepare(members)
            output.append(Byte.leftBrace)
            guard !prepared.isEmpty else {
                output.append(Byte.rightBrace)
                return
            }

            appendNewline(depth: depth + 1)
            for (index, member) in prepared.enumerated() {
                if let renamedKey = member.renamedKey {
                    JSONTransformer.appendJSONString(renamedKey, to: &output)
                } else {
                    output.append(contentsOf: source[member.member.rawKeyRange])
                }
                output.append(contentsOf: [Byte.colon, Byte.space])
                try write(member.member.value, depth: depth + 1)
                if index < prepared.count - 1 {
                    output.append(Byte.comma)
                    appendNewline(depth: depth + 1)
                }
            }
            appendNewline(depth: depth)
            output.append(Byte.rightBrace)
        }

        private func prepare(_ members: [Member]) throws -> [PreparedMember] {
            var prepared = members.map { member in
                PreparedMember(
                    member: member,
                    renamedKey: naming.map { JSONTransformer.rename(member.key, as: $0) }
                )
            }

            if naming != nil {
                var keys = Set<String>()
                for member in prepared {
                    let key = member.renamedKey ?? member.member.key
                    guard keys.insert(key).inserted else {
                        throw JSONTransformError.duplicateKey(key)
                    }
                }
            }

            if let ascending {
                prepared.sort { lhs, rhs in
                    let left = lhs.renamedKey ?? lhs.member.key
                    let right = rhs.renamedKey ?? rhs.member.key
                    return ascending ? left < right : left > right
                }
            }

            return prepared
        }

        private mutating func appendNewline(depth: Int) {
            output.append(Byte.newline)
            guard indentation > 0 else { return }
            output.append(contentsOf: repeatElement(
                Byte.space,
                count: depth * indentation
            ))
        }
    }

    private nonisolated struct PreparedMember {
        let member: Member
        let renamedKey: String?
    }

    // MARK: - Validation

    private nonisolated struct Validator {
        let bytes: [UInt8]
        var index = 0

        mutating func parseDocument() throws {
            skipWhitespace()
            try parseValue(depth: 0)
            skipWhitespace()
            guard index == bytes.count else { throw JSONTransformError.invalidJSON }
        }

        private mutating func parseValue(depth: Int) throws {
            try checkpoint()
            guard index < bytes.count, depth <= 1024 else {
                throw JSONTransformError.invalidJSON
            }

            switch bytes[index] {
            case Byte.leftBrace: try parseObject(depth: depth)
            case Byte.leftBracket: try parseArray(depth: depth)
            case Byte.quote: try parseString()
            case Byte.lowercaseT: try parseLiteral(Array("true".utf8))
            case Byte.lowercaseF: try parseLiteral(Array("false".utf8))
            case Byte.lowercaseN: try parseLiteral(Array("null".utf8))
            default: try parseNumber()
            }
        }

        private mutating func parseObject(depth: Int) throws {
            index += 1
            skipWhitespace()
            if consume(Byte.rightBrace) {
                return
            }

            while true {
                try parseString()
                skipWhitespace()
                try require(Byte.colon)
                skipWhitespace()
                try parseValue(depth: depth + 1)
                skipWhitespace()
                if consume(Byte.rightBrace) {
                    return
                }
                try require(Byte.comma)
                skipWhitespace()
            }
        }

        private mutating func parseArray(depth: Int) throws {
            index += 1
            skipWhitespace()
            if consume(Byte.rightBracket) {
                return
            }

            while true {
                try parseValue(depth: depth + 1)
                skipWhitespace()
                if consume(Byte.rightBracket) {
                    return
                }
                try require(Byte.comma)
                skipWhitespace()
            }
        }

        private mutating func parseString() throws {
            try require(Byte.quote)
            while index < bytes.count {
                try checkpoint()
                let byte = bytes[index]
                index += 1
                if byte == Byte.quote {
                    return
                }
                guard byte >= 0x20 else { throw JSONTransformError.invalidJSON }
                guard byte == Byte.backslash else { continue }
                guard index < bytes.count else { throw JSONTransformError.invalidJSON }
                let escaped = bytes[index]
                index += 1
                switch escaped {
                case Byte.quote, Byte.backslash, Byte.slash,
                     Byte.lowercaseB, Byte.lowercaseF, Byte.lowercaseN,
                     Byte.lowercaseR, Byte.lowercaseT:
                    break
                case Byte.lowercaseU:
                    let escapeStart = index - 2
                    guard let result = JSONTransformer.decodeUnicodeEscape(
                        bytes,
                        at: escapeStart
                    ) else {
                        throw JSONTransformError.invalidJSON
                    }
                    index = result.nextIndex
                default:
                    throw JSONTransformError.invalidJSON
                }
            }
            throw JSONTransformError.invalidJSON
        }

        private mutating func parseLiteral(_ literal: [UInt8]) throws {
            guard bytes[index...].starts(with: literal) else {
                throw JSONTransformError.invalidJSON
            }
            index += literal.count
        }

        private mutating func parseNumber() throws {
            if consume(Byte.minus), index >= bytes.count {
                throw JSONTransformError.invalidJSON
            }
            if consume(Byte.zero) {
                if index < bytes.count, JSONTransformer.isDigit(bytes[index]) {
                    throw JSONTransformError.invalidJSON
                }
            } else {
                guard index < bytes.count, JSONTransformer.isOneToNine(bytes[index]) else {
                    throw JSONTransformError.invalidJSON
                }
                index += 1
                while index < bytes.count, JSONTransformer.isDigit(bytes[index]) {
                    index += 1
                }
            }
            if consume(Byte.period) {
                guard index < bytes.count, JSONTransformer.isDigit(bytes[index]) else {
                    throw JSONTransformError.invalidJSON
                }
                while index < bytes.count, JSONTransformer.isDigit(bytes[index]) {
                    index += 1
                }
            }
            if index < bytes.count,
               bytes[index] == Byte.lowercaseE || bytes[index] == Byte.uppercaseE
            {
                index += 1
                if index < bytes.count,
                   bytes[index] == Byte.plus || bytes[index] == Byte.minus
                {
                    index += 1
                }
                guard index < bytes.count, JSONTransformer.isDigit(bytes[index]) else {
                    throw JSONTransformError.invalidJSON
                }
                while index < bytes.count, JSONTransformer.isDigit(bytes[index]) {
                    index += 1
                }
            }
        }

        private mutating func require(_ byte: UInt8) throws {
            guard consume(byte) else { throw JSONTransformError.invalidJSON }
        }

        private mutating func consume(_ byte: UInt8) -> Bool {
            guard index < bytes.count, bytes[index] == byte else { return false }
            index += 1
            return true
        }

        private mutating func skipWhitespace() {
            while index < bytes.count, JSONTransformer.isWhitespace(bytes[index]) {
                index += 1
            }
        }

        private func checkpoint() throws {
            if index.isMultiple(of: 16384) {
                try JSONTransformer.checkCancellation()
            }
        }
    }

    // MARK: - Key Naming

    private nonisolated static func rename(
        _ key: String,
        as naming: JSONKeyNaming
    ) -> String {
        let words = splitWords(key)
        guard !words.isEmpty else { return key }

        return switch naming {
        case .space:
            words.map { $0.lowercased() }.joined(separator: " ")
        case .title:
            words.map(capitalize).joined(separator: " ")
        case .kebab:
            words.map { $0.lowercased() }.joined(separator: "-")
        case .screamingSnake:
            words.map { $0.uppercased() }.joined(separator: "_")
        case .pascal:
            words.map(capitalize).joined()
        case .camel:
            words[0].lowercased() + words.dropFirst().map(capitalize).joined()
        case .snake:
            words.map { $0.lowercased() }.joined(separator: "_")
        }
    }

    private nonisolated static func splitWords(_ value: String) -> [String] {
        let characters = Array(value)
        var words: [String] = []
        var current = ""

        func flush(_ current: inout String, into words: inout [String]) {
            guard !current.isEmpty else { return }
            words.append(current)
            current.removeAll(keepingCapacity: true)
        }

        for index in characters.indices {
            let character = characters[index]
            if character == "_" || character == "-" || character.isWhitespace {
                flush(&current, into: &words)
                continue
            }

            let previous = index > characters.startIndex ? characters[index - 1] : nil
            let next = index < characters.index(before: characters.endIndex)
                ? characters[index + 1]
                : nil
            let startsWord = character.isUppercase && (
                previous?.isLowercase == true
                    || previous?.isNumber == true
                    || (previous?.isUppercase == true && next?.isLowercase == true)
            )

            if startsWord {
                flush(&current, into: &words)
            }
            current.append(character)
        }

        flush(&current, into: &words)
        return words
    }

    private nonisolated static func capitalize(_ word: String) -> String {
        guard let first = word.first else { return word }
        return first.uppercased() + word.dropFirst().lowercased()
    }

    // MARK: - Encoding Helpers

    private nonisolated static func appendJSONString(
        _ value: String,
        to output: inout [UInt8]
    ) {
        output.append(Byte.quote)
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x08:
                output.append(contentsOf: [Byte.backslash, Byte.lowercaseB])
            case 0x09:
                output.append(contentsOf: [Byte.backslash, Byte.lowercaseT])
            case 0x0A:
                output.append(contentsOf: [Byte.backslash, Byte.lowercaseN])
            case 0x0C:
                output.append(contentsOf: [Byte.backslash, Byte.lowercaseF])
            case 0x0D:
                output.append(contentsOf: [Byte.backslash, Byte.lowercaseR])
            case 0x22:
                output.append(contentsOf: [Byte.backslash, Byte.quote])
            case 0x5C:
                output.append(contentsOf: [Byte.backslash, Byte.backslash])
            case 0x00 ... 0x1F:
                appendUnicodeEscape(UInt16(scalar.value), to: &output)
            default:
                appendUTF8(scalar, to: &output)
            }
        }
        output.append(Byte.quote)
    }

    private nonisolated static func decodeUnicodeEscape(
        _ bytes: [UInt8],
        at index: Int
    ) -> (scalar: UnicodeScalar, nextIndex: Int)? {
        guard index + 5 < bytes.count,
              bytes[index] == Byte.backslash,
              bytes[index + 1] == Byte.lowercaseU,
              let first = hexValue(bytes[(index + 2) ... (index + 5)])
        else { return nil }

        if (0xD800 ... 0xDBFF).contains(first) {
            let secondStart = index + 6
            guard secondStart + 5 < bytes.count,
                  bytes[secondStart] == Byte.backslash,
                  bytes[secondStart + 1] == Byte.lowercaseU,
                  let second = hexValue(bytes[(secondStart + 2) ... (secondStart + 5)]),
                  (0xDC00 ... 0xDFFF).contains(second)
            else { return nil }

            let value = 0x10000
                + ((UInt32(first) - 0xD800) << 10)
                + (UInt32(second) - 0xDC00)
            guard let scalar = UnicodeScalar(value) else { return nil }
            return (scalar, secondStart + 6)
        }

        guard !(0xDC00 ... 0xDFFF).contains(first),
              let scalar = UnicodeScalar(UInt32(first))
        else { return nil }
        return (scalar, index + 6)
    }

    private nonisolated static func appendUnicodeEscape(
        _ value: UInt16,
        to output: inout [UInt8]
    ) {
        output.append(contentsOf: [Byte.backslash, Byte.lowercaseU])
        for shift in stride(from: 12, through: 0, by: -4) {
            let digit = UInt8((value >> UInt16(shift)) & 0xF)
            output.append(digit < 10 ? Byte.zero + digit : Byte.uppercaseA + digit - 10)
        }
    }

    private nonisolated static func appendUTF8(
        _ scalar: UnicodeScalar,
        to output: inout [UInt8]
    ) {
        output.append(contentsOf: String(scalar).utf8)
    }

    private nonisolated static func hexValue(_ bytes: ArraySlice<UInt8>) -> UInt16? {
        var result: UInt16 = 0
        for byte in bytes {
            let digit: UInt16
            switch byte {
            case Byte.zero ... Byte.nine:
                digit = UInt16(byte - Byte.zero)
            case Byte.uppercaseA ... Byte.uppercaseF:
                digit = UInt16(byte - Byte.uppercaseA + 10)
            case Byte.lowercaseA ... Byte.lowercaseF:
                digit = UInt16(byte - Byte.lowercaseA + 10)
            default:
                return nil
            }
            result = result * 16 + digit
        }
        return result
    }

    private nonisolated static func nextToken(
        in bytes: [UInt8],
        after index: Int
    ) -> UInt8? {
        bytes.dropFirst(index + 1).first(where: { !isWhitespace($0) })
    }

    private nonisolated static func matchingClose(for byte: UInt8) -> UInt8? {
        switch byte {
        case Byte.leftBrace: Byte.rightBrace
        case Byte.leftBracket: Byte.rightBracket
        default: nil
        }
    }

    private nonisolated static func matchingOpen(for byte: UInt8) -> UInt8? {
        switch byte {
        case Byte.rightBrace: Byte.leftBrace
        case Byte.rightBracket: Byte.leftBracket
        default: nil
        }
    }

    private nonisolated static func isWhitespace(_ byte: UInt8) -> Bool {
        byte == Byte.space
            || byte == Byte.tab
            || byte == Byte.newline
            || byte == Byte.carriageReturn
    }

    private nonisolated static func isDigit(_ byte: UInt8) -> Bool {
        (Byte.zero ... Byte.nine).contains(byte)
    }

    private nonisolated static func isOneToNine(_ byte: UInt8) -> Bool {
        ((Byte.zero + 1) ... Byte.nine).contains(byte)
    }

    private nonisolated static func checkCancellation() throws {
        if withUnsafeCurrentTask(body: { $0?.isCancelled ?? false }) {
            throw JSONTransformError.cancelled
        }
    }

    private enum Byte {
        nonisolated static let backspace: UInt8 = 0x08
        nonisolated static let tab: UInt8 = 0x09
        nonisolated static let newline: UInt8 = 0x0A
        nonisolated static let formFeed: UInt8 = 0x0C
        nonisolated static let carriageReturn: UInt8 = 0x0D
        nonisolated static let space: UInt8 = 0x20
        nonisolated static let quote: UInt8 = 0x22
        nonisolated static let plus: UInt8 = 0x2B
        nonisolated static let comma: UInt8 = 0x2C
        nonisolated static let minus: UInt8 = 0x2D
        nonisolated static let period: UInt8 = 0x2E
        nonisolated static let slash: UInt8 = 0x2F
        nonisolated static let zero: UInt8 = 0x30
        nonisolated static let nine: UInt8 = 0x39
        nonisolated static let colon: UInt8 = 0x3A
        nonisolated static let uppercaseA: UInt8 = 0x41
        nonisolated static let uppercaseE: UInt8 = 0x45
        nonisolated static let uppercaseF: UInt8 = 0x46
        nonisolated static let leftBracket: UInt8 = 0x5B
        nonisolated static let backslash: UInt8 = 0x5C
        nonisolated static let rightBracket: UInt8 = 0x5D
        nonisolated static let leftBrace: UInt8 = 0x7B
        nonisolated static let rightBrace: UInt8 = 0x7D
        nonisolated static let lowercaseA: UInt8 = 0x61
        nonisolated static let lowercaseB: UInt8 = 0x62
        nonisolated static let lowercaseE: UInt8 = 0x65
        nonisolated static let lowercaseF: UInt8 = 0x66
        nonisolated static let lowercaseN: UInt8 = 0x6E
        nonisolated static let lowercaseR: UInt8 = 0x72
        nonisolated static let lowercaseT: UInt8 = 0x74
        nonisolated static let lowercaseU: UInt8 = 0x75
    }
}
