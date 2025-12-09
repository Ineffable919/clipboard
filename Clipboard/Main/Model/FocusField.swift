//
//  FocusField.swift
//  Clipboard
//
//  Created by crown on 2025/12/09.
//

import Foundation

enum FocusField: Hashable {
    case search
    case newChip
    case editChip
    case history
    case popover

    static func fromOptional(_ field: FocusField?) -> FocusField {
        field ?? .history
    }

    var asOptional: FocusField? {
        switch self {
        case .search, .newChip, .editChip: self
        case .history, .popover: nil
        }
    }
}
