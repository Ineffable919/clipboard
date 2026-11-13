//
//  JSONTransformError.swift
//  Clipboard
//
//  Created by crown on 2026/7/21
//

enum JSONTransformError: Error, Equatable, Sendable {
    case invalidJSON
    case duplicateKey(String)
    case cancelled
}
