//
//  FocusField.swift
//  Clipboard
//
//  Created by crown on 2025/12/09.
//

import Foundation

enum FocusField: Hashable, Sendable {
    case search
    case newChip
    case editChip
    case history
    case popover
    case filter

    var requiresSystemFocus: Bool {
        switch self {
        case .search, .newChip, .editChip:
            return true
        case .history, .popover, .filter:
            return false
        }
    }
}
