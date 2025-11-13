//
//  EnvironmentValues+Extensions.swift
//  Clipboard
//
//  Created by crown on 2025/9/24.
//

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
