//
//  PasteContent.swift
//  Clipboard
//
//  Created by crown on 2026/9/2
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
