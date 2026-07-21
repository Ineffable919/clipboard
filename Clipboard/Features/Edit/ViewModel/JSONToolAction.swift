//
//  JSONToolAction.swift
//  Clipboard
//

enum JSONToolAction: Sendable {
    case format(JSONIndentation)
    case compact
    case addEscapes
    case removeEscapes
    case encodeUnicode
    case decodeUnicode
    case sortKeys(ascending: Bool, indentation: JSONIndentation)
    case renameKeys(JSONKeyNaming, indentation: JSONIndentation)
}
