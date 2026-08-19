//
//  WelcomePage.swift
//  Clipboard
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
            .welcomeIntroductionTitle
        case .shortcut:
            .welcomeShortcutTitle
        case .permission:
            .welcomePermissionTitle
        }
    }

    var next: WelcomePage? {
        WelcomePage(rawValue: rawValue + 1)
    }

    var previous: WelcomePage? {
        WelcomePage(rawValue: rawValue - 1)
    }
}
