//
//  PasteContent.swift
//  Clipboard
//

import Foundation

struct PasteContent {
    let type: PasteboardType
    let data: Data
    let showData: Data?
    let searchText: String
    let length: Int
    let tag: String
}
