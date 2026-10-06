import Foundation

extension JSONTransformer {
    // MARK: - Validation

    nonisolated struct Validator {
        let bytes: UnsafeBufferPointer<UInt8>
        var index = 0
        var indentation: Int?
        var rewritesWhitespace = false
        var output: [UInt8] = []
        private var linePrefix: [UInt8] = [Byte.newline]
        private var nextCancellationCheck = 0

        init(bytes: UnsafeBufferPointer<UInt8>, indentation: Int? = nil, rewritesWhitespace: Bool = false) {
            self.bytes = bytes
            self.indentation = indentation
            self.rewritesWhitespace = rewritesWhitespace
        }

        private mutating func emit(_ byte: UInt8) {
            if rewritesWhitespace { output.append(byte) }
        }

        private mutating func emitToken(from start: Int) {
            if rewritesWhitespace { output.append(contentsOf: bytes[start..<index]) }
        }

        private mutating func emitNewline(depth: Int) {
            guard let indentation else { return }
            let count = 1 + depth * indentation
            if linePrefix.count < count {
                linePrefix.append(contentsOf: repeatElement(Byte.space, count: count - linePrefix.count))
            }
            output.append(contentsOf: linePrefix.prefix(count))
        }

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
            case Byte.lowercaseT: try parseLiteral("true")
            case Byte.lowercaseF: try parseLiteral("false")
            case Byte.lowercaseN: try parseLiteral("null")
            default: try parseNumber()
            }
        }

        private mutating func parseObject(depth: Int) throws {
            index += 1
            emit(Byte.leftBrace)
            skipWhitespace()
            if consume(Byte.rightBrace) {
                emit(Byte.rightBrace)
                return
            }
            emitNewline(depth: depth + 1)
            while true {
                try parseString()
                skipWhitespace()
                try require(Byte.colon)
                emit(Byte.colon)
                if indentation != nil { emit(Byte.space) }
                skipWhitespace()
                try parseValue(depth: depth + 1)
                skipWhitespace()
                if consume(Byte.rightBrace) {
                    emitNewline(depth: depth)
                    emit(Byte.rightBrace)
                    return
                }
                try require(Byte.comma)
                emit(Byte.comma)
                emitNewline(depth: depth + 1)
                skipWhitespace()
            }
        }

        private mutating func parseArray(depth: Int) throws {
            index += 1
            emit(Byte.leftBracket)
            skipWhitespace()
            if consume(Byte.rightBracket) {
                emit(Byte.rightBracket)
                return
            }
            emitNewline(depth: depth + 1)
            while true {
                try parseValue(depth: depth + 1)
                skipWhitespace()
                if consume(Byte.rightBracket) {
                    emitNewline(depth: depth)
                    emit(Byte.rightBracket)
                    return
                }
                try require(Byte.comma)
                emit(Byte.comma)
                emitNewline(depth: depth + 1)
                skipWhitespace()
            }
        }

        private mutating func parseString() throws {
            let start = index
            try checkpoint()
            try require(Byte.quote)
            let raw = UnsafeRawBufferPointer(bytes)
            var scalarEnd = index
            while index < bytes.count {
                // 普通字符串按八字节跳过，遇到引号、转义或控制字符再逐字节检查
                if index >= scalarEnd {
                    try skipPlainString(raw)
                    scalarEnd = index + 8
                }
                let byte = bytes[index]
                index += 1
                if byte == Byte.quote {
                    emitToken(from: start)
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

        private func containsZero(_ word: UInt64) -> Bool {
            // 每个字节减一后的借位位用于检测零字节
            (word &- 0x0101_0101_0101_0101) & ~word & 0x8080_8080_8080_8080 != 0
        }

        private mutating func skipPlainString(_ raw: UnsafeRawBufferPointer) throws {
            while bytes.count - index > 8 {
                if index >= nextCancellationCheck { try checkpoint() }
                let word = raw.loadUnaligned(fromByteOffset: index, as: UInt64.self)
                guard !containsZero(word ^ 0x2222_2222_2222_2222),
                      !containsZero(word ^ 0x5C5C_5C5C_5C5C_5C5C),
                      !containsZero(word & 0xE0E0_E0E0_E0E0_E0E0) else { return }
                index += 8
            }
        }

        private mutating func parseLiteral(_ literal: StaticString) throws {
            let start = index
            let matches = literal.withUTF8Buffer { bytes[index...].starts(with: $0) }
            guard matches else {
                throw JSONTransformError.invalidJSON
            }
            index += literal.utf8CodeUnitCount
            emitToken(from: start)
        }

        private mutating func parseNumber() throws {
            let start = index
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
                try skipDigits()
            }
            if consume(Byte.period) {
                guard index < bytes.count, JSONTransformer.isDigit(bytes[index]) else {
                    throw JSONTransformError.invalidJSON
                }
                try skipDigits()
            }
            if index < bytes.count,
               bytes[index] == Byte.lowercaseE || bytes[index] == Byte.uppercaseE {
                index += 1
                if index < bytes.count,
                   bytes[index] == Byte.plus || bytes[index] == Byte.minus {
                    index += 1
                }
                guard index < bytes.count, JSONTransformer.isDigit(bytes[index]) else {
                    throw JSONTransformError.invalidJSON
                }
                try skipDigits()
            }
            emitToken(from: start)
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
            let raw = UnsafeRawBufferPointer(bytes)
            while index < bytes.count {
                if index >= nextCancellationCheck {
                    if Task.isCancelled { return }
                    nextCancellationCheck = index + 16384
                }
                if bytes.count - index >= 8,
                   raw.loadUnaligned(fromByteOffset: index, as: UInt64.self) == 0x2020_2020_2020_2020 {
                    index += 8
                    continue
                }
                let byte = bytes[index]
                guard byte == 32 || byte == 9 || byte == 10 || byte == 13 else { return }
                index += 1
            }
        }

        private mutating func skipDigits() throws {
            while index < bytes.count, bytes[index] >= 48, bytes[index] <= 57 {
                if index >= nextCancellationCheck { try checkpoint() }
                index += 1
            }
        }

        private mutating func checkpoint() throws {
            if index >= nextCancellationCheck {
                try JSONTransformer.checkCancellation()
                nextCancellationCheck = index + 16384
            }
        }
    }

}
