//
//  PasteIdentity.swift
//  Clipboard
//
//  Created by crown on 2026/9/5
//

struct PasteIdentity: Sendable {
    let id: Int64
    let storedUniqueId: String
    let correctUniqueId: String
    let timestamp: Int64
    let group: Int
}
