//
//  PasteContent.swift
//  Clipboard
//

import Foundation

nonisolated struct PasteContent: Sendable {
    let type: PasteboardType
    let data: Data
    let showData: Data?
    let searchText: String
    let length: Int
    let tag: String
}
