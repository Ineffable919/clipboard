//
//  JSONToolAction.swift
//  Clipboard
//
//  Created by crown on 2026/7/21
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
