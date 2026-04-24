//
//  InputTag.swift
//  Clipboard
//
//  Created by crown on 2025/12/17.
//

import SwiftUI

struct InputTag: Identifiable, Equatable {
    let id = UUID()
    let icon: AnyView
    let label: String
    let type: TagType
    let associatedValue: String
    let appPath: String?

    init(icon: AnyView, label: String, type: TagType, associatedValue: String, appPath: String? = nil) {
        self.icon = icon
        self.label = label
        self.type = type
        self.associatedValue = associatedValue
        self.appPath = appPath
    }

    enum TagType {
        case filterType
        case filterApp
        case filterDate
    }

    static func == (lhs: InputTag, rhs: InputTag) -> Bool {
        lhs.type == rhs.type && lhs.associatedValue == rhs.associatedValue
    }
}
