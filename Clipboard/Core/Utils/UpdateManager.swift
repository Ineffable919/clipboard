//
//  UpdateManager.swift
//  Clipboard
//
//  Created by crown on 2025/12/30
//

import AppKit

@MainActor
@Observable
final class UpdateManager {
    static let shared = UpdateManager()

    private(set) var availableVersion: String?

    var hasUpdate: Bool { availableVersion != nil }

    private init() {}

    func setUpdateAvailable(version: String, build: String) {
        availableVersion = version == build ? version : "\(version)(\(build))"
    }

    func clearUpdate() {
        availableVersion = nil
    }

    func makeMenuItem(target: AnyObject?, action: Selector) -> NSMenuItem? {
        guard let availableVersion else { return nil }
        let item = NSMenuItem(
            title: String(localized: .updateAvailable(availableVersion)),
            action: action,
            keyEquivalent: ""
        )
        item.target = target
        if #available(macOS 26.0, *),
            let image = NSImage(systemSymbolName: "arrow.up.circle.dotted", accessibilityDescription: nil)
        {
            item.image = image.withSymbolConfiguration(.init(pointSize: 16, weight: .semibold))
        }
        return item
    }
}
