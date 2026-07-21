//
//  JSONSyntaxHighlighter.swift
//  Clipboard
//

import Foundation

enum JSONSyntaxHighlighter {
    nonisolated enum Kind: Sendable {
        case key
        case string
        case number
        case literal
        case punctuation
    }

    nonisolated struct Span: Sendable {
        let range: NSRange
        let kind: Kind
    }

    nonisolated static func spans(
        in text: String,
        offset: Int
    ) -> [Span] {
        let source = text as NSString
        var result: [Span] = []
        result.reserveCapacity(max(16, source.length / 12))
        var index = 0

        while index < source.length {
            let character = source.character(at: index)

            if character == CharacterCode.quote {
                let start = index
                index += 1
                var escaped = false
                while index < source.length {
                    let current = source.character(at: index)
                    index += 1
                    if escaped {
                        escaped = false
                    } else if current == CharacterCode.backslash {
                        escaped = true
                    } else if current == CharacterCode.quote {
                        break
                    }
                }

                var lookahead = index
                while lookahead < source.length,
                      isWhitespace(source.character(at: lookahead))
                {
                    lookahead += 1
                }
                let kind: Kind = lookahead < source.length
                    && source.character(at: lookahead) == CharacterCode.colon
                    ? .key
                    : .string
                result.append(Span(
                    range: NSRange(location: offset + start, length: index - start),
                    kind: kind
                ))
                continue
            }

            if character == CharacterCode.minus || isDigit(character) {
                let start = index
                index += 1
                while index < source.length,
                      isNumberCharacter(source.character(at: index))
                {
                    index += 1
                }
                result.append(Span(
                    range: NSRange(location: offset + start, length: index - start),
                    kind: .number
                ))
                continue
            }

            if isLiteralStart(character) {
                let start = index
                while index < source.length,
                      isASCIILetter(source.character(at: index))
                {
                    index += 1
                }
                result.append(Span(
                    range: NSRange(location: offset + start, length: index - start),
                    kind: .literal
                ))
                continue
            }

            if isPunctuation(character) {
                result.append(Span(
                    range: NSRange(location: offset + index, length: 1),
                    kind: .punctuation
                ))
            }
            index += 1
        }

        return result
    }

    private nonisolated static func isWhitespace(_ value: unichar) -> Bool {
        value == CharacterCode.space
            || value == CharacterCode.tab
            || value == CharacterCode.newline
            || value == CharacterCode.carriageReturn
    }

    private nonisolated static func isDigit(_ value: unichar) -> Bool {
        (CharacterCode.zero ... CharacterCode.nine).contains(value)
    }

    private nonisolated static func isNumberCharacter(_ value: unichar) -> Bool {
        isDigit(value)
            || value == CharacterCode.minus
            || value == CharacterCode.plus
            || value == CharacterCode.period
            || value == CharacterCode.lowercaseE
            || value == CharacterCode.uppercaseE
    }

    private nonisolated static func isLiteralStart(_ value: unichar) -> Bool {
        value == CharacterCode.lowercaseT
            || value == CharacterCode.lowercaseF
            || value == CharacterCode.lowercaseN
    }

    private nonisolated static func isASCIILetter(_ value: unichar) -> Bool {
        (CharacterCode.lowercaseA ... CharacterCode.lowercaseZ).contains(value)
            || (CharacterCode.uppercaseA ... CharacterCode.uppercaseZ).contains(value)
    }

    private nonisolated static func isPunctuation(_ value: unichar) -> Bool {
        value == CharacterCode.leftBrace
            || value == CharacterCode.rightBrace
            || value == CharacterCode.leftBracket
            || value == CharacterCode.rightBracket
            || value == CharacterCode.colon
            || value == CharacterCode.comma
    }

    private nonisolated enum CharacterCode {
        nonisolated static let tab: unichar = 0x09
        nonisolated static let newline: unichar = 0x0A
        nonisolated static let carriageReturn: unichar = 0x0D
        nonisolated static let space: unichar = 0x20
        nonisolated static let quote: unichar = 0x22
        nonisolated static let plus: unichar = 0x2B
        nonisolated static let comma: unichar = 0x2C
        nonisolated static let minus: unichar = 0x2D
        nonisolated static let period: unichar = 0x2E
        nonisolated static let zero: unichar = 0x30
        nonisolated static let nine: unichar = 0x39
        nonisolated static let colon: unichar = 0x3A
        nonisolated static let uppercaseA: unichar = 0x41
        nonisolated static let uppercaseE: unichar = 0x45
        nonisolated static let uppercaseZ: unichar = 0x5A
        nonisolated static let leftBracket: unichar = 0x5B
        nonisolated static let backslash: unichar = 0x5C
        nonisolated static let rightBracket: unichar = 0x5D
        nonisolated static let lowercaseA: unichar = 0x61
        nonisolated static let lowercaseE: unichar = 0x65
        nonisolated static let lowercaseF: unichar = 0x66
        nonisolated static let lowercaseN: unichar = 0x6E
        nonisolated static let lowercaseT: unichar = 0x74
        nonisolated static let lowercaseZ: unichar = 0x7A
        nonisolated static let leftBrace: unichar = 0x7B
        nonisolated static let rightBrace: unichar = 0x7D
    }
}
