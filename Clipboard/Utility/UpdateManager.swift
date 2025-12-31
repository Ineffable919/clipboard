//
//  UpdateManager.swift
//  Clipboard
//
//  Created by crown on 2025/12/30.
//

import Foundation

@MainActor
@Observable
final class UpdateManager {
    static let shared = UpdateManager()

    private(set) var hasUpdate: Bool = false

    private(set) var availableVersion: String?

    private init() {}

    func setUpdateAvailable(version: String) {
        hasUpdate = true
        availableVersion = version
    }

    func clearUpdate() {
        hasUpdate = false
        availableVersion = nil
    }
}
