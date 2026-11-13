//
//  WelcomePage.swift
//  Clipboard
//
//  Created by crown on 2026/8/19
//

import SwiftUI

enum WelcomePage: Int, CaseIterable, Identifiable {
    case introduction
    case shortcut
    case permission

    var id: Int {
        rawValue
    }

    var accessibilityLabel: LocalizedStringResource {
        switch self {
        case .introduction:
            .introTitle
        case .shortcut:
            .shortcutTitle
        case .permission:
            .permissionTitle
        }
    }

    var next: WelcomePage? {
        WelcomePage(rawValue: rawValue + 1)
    }

    var previous: WelcomePage? {
        WelcomePage(rawValue: rawValue - 1)
    }
}
