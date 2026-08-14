//
//  SettingViewModel.swift
//  Clipboard
//
//  Created by crown on 2026/4/18.
//

import AppKit
import Foundation
import SwiftUI

@MainActor
@Observable final class SettingViewModel {
    var selectedPage: SettingPage = .general
    private(set) var hasAccessibilityPermission = AXIsProcessTrusted()

    func navigateTo(_ page: SettingPage) {
        selectedPage = page
    }

    func refreshAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }

        NSWorkspace.shared.open(url)
    }
}
