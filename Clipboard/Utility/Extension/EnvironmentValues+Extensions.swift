//
//  EnvironmentValues+Extensions.swift
//  Clipboard
//
//  Created by crown on 2025/9/24.
//

import Sparkle
import SwiftUI

private struct IsFocusedKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var isFocused: Bool {
        get { self[IsFocusedKey.self] }
        set { self[IsFocusedKey.self] = newValue }
    }
}

// MARK: - Sparkle Updater Environment Key

private struct UpdaterControllerKey: EnvironmentKey {
    static let defaultValue: SPUStandardUpdaterController? = nil
}

extension EnvironmentValues {
    var updaterController: SPUStandardUpdaterController? {
        get { self[UpdaterControllerKey.self] }
        set { self[UpdaterControllerKey.self] = newValue }
    }
}
