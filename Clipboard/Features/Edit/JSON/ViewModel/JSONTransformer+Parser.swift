import Foundation

extension JSONTransformer {
    nonisolated struct TreeParser {
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

                try parseEscape(escaped, into: &decoded, shouldDecode: shouldDecode)
            }

            throw JSONTransformError.invalidJSON
        }

        private mutating func parseEscape(
            _ escaped: UInt8, into decoded: inout [UInt8], shouldDecode: Bool
        ) throws {
            if escaped == Byte.lowercaseU {
                guard let result = JSONTransformer.decodeUnicodeEscape(bytes, at: index - 2) else {
                    throw JSONTransformError.invalidJSON
                }
                if shouldDecode { JSONTransformer.appendUTF8(result.scalar, to: &decoded) }
                index = result.nextIndex
                return
            }
            guard let byte = JSONTransformer.escapedByte(escaped) else {
                throw JSONTransformError.invalidJSON
            }
            if shouldDecode { decoded.append(byte) }
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

            try parseExponent()
            return start ..< index
        }

        private mutating func parseExponent() throws {
            if index < bytes.count,
               bytes[index] == Byte.lowercaseE || bytes[index] == Byte.uppercaseE {
                index += 1
                if index < bytes.count,
                   bytes[index] == Byte.plus || bytes[index] == Byte.minus {
                    index += 1
                }
                guard index < bytes.count, isDigit(bytes[index]) else {
                    throw JSONTransformError.invalidJSON
                }
                while index < bytes.count, isDigit(bytes[index]) {
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

}
