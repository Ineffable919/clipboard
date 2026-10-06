import Foundation

extension JSONTransformer {
    // MARK: - Escaping

    nonisolated static func addEscapes(_ text: String) throws -> String {
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

        return decode(output)
    }

    nonisolated static func removeEscapes(_ text: String) throws -> String {
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

            if let byte = escapedByte(bytes[index + 1]) {
                output.append(byte)
                index += 2
            } else if bytes[index + 1] == Byte.lowercaseU,
                      let decoded = decodeUnicodeEscape(bytes, at: index) {
                appendUTF8(decoded.scalar, to: &output)
                index = decoded.nextIndex
            } else {
                output.append(bytes[index])
                index += 1
            }
        }

        return decode(output)
    }

    nonisolated static func escapedByte(_ byte: UInt8) -> UInt8? {
        switch byte {
        case Byte.quote, Byte.backslash, Byte.slash: byte
        case Byte.lowercaseB: Byte.backspace
        case Byte.lowercaseF: Byte.formFeed
        case Byte.lowercaseN: Byte.newline
        case Byte.lowercaseR: Byte.carriageReturn
        case Byte.lowercaseT: Byte.tab
        default: nil
        }
    }

    nonisolated static func encodeUnicode(_ text: String) throws -> String {
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

        return decode(output)
    }

    nonisolated static func decodeUnicode(_ text: String) throws -> String {
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
                   let decoded = decodeUnicodeEscape(bytes, at: index) {
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

        return decode(output)
    }

}
