//
//  JSONIndentation.swift
//  Clipboard
//

enum JSONIndentation: Int, CaseIterable, Sendable {
    case none = 0
    case two = 2
    case four = 4
    case six = 6
    case eight = 8

    nonisolated static func detect(in text: String) -> Self {
        var spaces = 0
        var atLineStart = false
        for byte in text.utf8.prefix(16384) {
            if byte == 10 || byte == 13 {
                spaces = 0
                atLineStart = true
            } else if atLineStart, byte == 32 {
                spaces += 1
            } else if atLineStart {
                if spaces > 0, let indentation = Self(rawValue: spaces) {
                    return indentation
                }
                atLineStart = false
            }
        }
        return .none
    }
}
