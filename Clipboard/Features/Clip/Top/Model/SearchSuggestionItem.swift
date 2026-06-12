//
//  SearchSuggestionItem.swift
//  Clipboard
//
//  联想列表数据模型
//

import AppKit

struct SearchSuggestionItem: Equatable {
    let title: String
    let icon: NSImage?
    let action: SuggestionAction

    enum SuggestionAction: Equatable {
        case toggleType(PasteModelType)
        case toggleApp(String, String?)
        case setDate(DateFilterOption)
        case setGroup(Int)
    }

    static func == (lhs: SearchSuggestionItem, rhs: SearchSuggestionItem) -> Bool {
        lhs.action == rhs.action
    }
}
