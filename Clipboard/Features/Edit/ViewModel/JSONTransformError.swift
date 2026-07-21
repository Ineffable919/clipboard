//
//  JSONTransformError.swift
//  Clipboard
//

enum JSONTransformError: Error, Equatable, Sendable {
    case invalidJSON
    case duplicateKey(String)
    case cancelled
}
