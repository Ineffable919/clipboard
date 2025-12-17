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
    let associatedValue: String  // 用于关联具体的类型/应用/日期值
    let appPath: String?  // 应用路径，仅用于 filterApp 类型

    init(icon: AnyView, label: String, type: TagType, associatedValue: String, appPath: String? = nil) {
        self.icon = icon
        self.label = label
        self.type = type
        self.associatedValue = associatedValue
        self.appPath = appPath
    }

    enum TagType {
        case filterType  // 类型筛选
        case filterApp  // 应用筛选
        case filterDate  // 日期筛选
    }
    
    static func == (lhs: InputTag, rhs: InputTag) -> Bool {
        lhs.type == rhs.type && lhs.associatedValue == rhs.associatedValue
    }
}
