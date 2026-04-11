//
//  FocusRegion.swift
//  Clipboard
//
//  Created by crown on 2026/4/11.
//

enum FocusRegion: CustomStringConvertible {
    case collection
    case search

    var description: String {
        switch self {
        case .collection: "collection"
        case .search: "search"
        }
    }
}
