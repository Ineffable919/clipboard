import Foundation

extension JSONTransformer {
    nonisolated static func decode(_ bytes: [UInt8]) -> String {
        // 转换输出是 UTF-8 字节，保留非可选解码以避免额外校验和数据丢失
        // swiftlint:disable:next optional_data_string_conversion
        String(decoding: bytes, as: UTF8.self)
    }

    // MARK: - Key Naming

    nonisolated static func rename(
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

    nonisolated static func splitWords(_ value: String) -> [String] {
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

    nonisolated static func capitalize(_ word: String) -> String {
        guard let first = word.first else { return word }
        return first.uppercased() + word.dropFirst().lowercased()
    }

    // MARK: - Encoding Helpers

    nonisolated static func appendJSONString(
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

    nonisolated static func decodeUnicodeEscape<Bytes: RandomAccessCollection>(
        _ bytes: Bytes,
        at index: Int
    ) -> (scalar: UnicodeScalar, nextIndex: Int)? where Bytes.Element == UInt8, Bytes.Index == Int {
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

    nonisolated static func appendUnicodeEscape(
        _ value: UInt16,
        to output: inout [UInt8]
    ) {
        output.append(contentsOf: [Byte.backslash, Byte.lowercaseU])
        for shift in stride(from: 12, through: 0, by: -4) {
            let digit = UInt8((value >> UInt16(shift)) & 0xF)
            output.append(digit < 10 ? Byte.zero + digit : Byte.uppercaseA + digit - 10)
        }
    }

    nonisolated static func appendUTF8(
        _ scalar: UnicodeScalar,
        to output: inout [UInt8]
    ) {
        output.append(contentsOf: String(scalar).utf8)
    }

    nonisolated static func hexValue(_ bytes: some Collection<UInt8>) -> UInt16? {
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

    nonisolated static func isWhitespace(_ byte: UInt8) -> Bool {
        byte == Byte.space
            || byte == Byte.tab
            || byte == Byte.newline
            || byte == Byte.carriageReturn
    }

    nonisolated static func isDigit(_ byte: UInt8) -> Bool {
        (Byte.zero ... Byte.nine).contains(byte)
    }

    nonisolated static func isOneToNine(_ byte: UInt8) -> Bool {
        ((Byte.zero + 1) ... Byte.nine).contains(byte)
    }

    nonisolated static func checkCancellation() throws {
        if withUnsafeCurrentTask(body: { $0?.isCancelled ?? false }) {
            throw JSONTransformError.cancelled
        }
    }

    enum Byte {
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
    }}
