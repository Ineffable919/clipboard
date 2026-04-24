//
//  LegacyConfigMigrator.swift
//  Clipboard
//
//  Created by crown on 2026/1/11.
//

import AppKit
import UniformTypeIdentifiers

final class LegacyConfigMigrator {
    static let shared = LegacyConfigMigrator()

    private let migratedFlagKey = "userDefaultsMigrated"

    func startMigrationIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedFlagKey) else {
            log.info("偏好与设置已完成迁移或用户已跳过")
            return
        }

        presentMigrationAlert()
    }

    // MARK: - 提示用户（导入 / 跳过）

    private func presentMigrationAlert() {
        let alert = NSAlert()
        alert.messageText = String(localized: .importAsk)
        alert.addButton(withTitle: String(localized: .importAction))
        alert.addButton(withTitle: String(localized: .skip))

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            presentLegacyPlistPicker()
        } else {
            skipMigration()
        }
    }

    // MARK: - 选择 plist

    private func presentLegacyPlistPicker() {
        let panel = NSOpenPanel()
        panel.title = String(localized: .chooseFile)
        panel.message = String(localized: .choosePlist)
        panel.prompt = String(localized: .importAction)

        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.propertyList]

        let preferencesDir = URL.homeDirectory.appending(path: "Library/Preferences")
        let targetPlistURL = preferencesDir.appending(path: "com.crown.clipboard.plist")

        if FileManager.default.fileExists(atPath: targetPlistURL.path) {
            panel.directoryURL = preferencesDir
            panel.nameFieldStringValue = "com.crown.clipboard.plist"
        } else {
            panel.directoryURL = preferencesDir
        }

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                self.skipMigration()
                return
            }

            guard url.lastPathComponent == "com.crown.clipboard.plist" else {
                self.presentWrongFileAlert()
                return
            }

            self.importLegacyPlist(at: url)
        }
    }

    // MARK: - 读取并迁移

    private func importLegacyPlist(at url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            log.warn("无法访问安全作用域资源")
            presentResultAlert(success: false)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)

            guard
                let dict = try PropertyListSerialization.propertyList(
                    from: data,
                    options: [],
                    format: nil
                ) as? [String: Any]
            else {
                log.error("plist 格式不合法")
                presentResultAlert(success: false)
                return
            }

            migrateToUserDefaults(legacyConfigs: dict)

        } catch {
            log.error("读取旧配置失败: \(error.localizedDescription)")
            presentResultAlert(success: false)
        }
    }

    // MARK: - 数据迁移

    private func migrateToUserDefaults(legacyConfigs: [String: Any]) {
        let currentDefaults = UserDefaults.standard
        var migratedKeys: [String] = []

        let validKeys = Set(PrefKey.allCases.map(\.rawValue))

        for (key, value) in legacyConfigs {
            if validKeys.contains(key) {
                currentDefaults.set(value, forKey: key)
                migratedKeys.append(key)
                log.info("✅ 迁移配置项: \(key)")
            } else {
                log.info("⏭️ 跳过未知配置项: \(key)")
            }
        }

        currentDefaults.set(true, forKey: migratedFlagKey)

        log.info("🎉 迁移完成，共迁移 \(migratedKeys.count) 项，已迁移的配置项: \(migratedKeys.joined(separator: ", "))")

        presentResultAlert(success: true)
    }

    private func skipMigration() {
        log.info("用户跳过迁移")
        UserDefaults.standard.set(true, forKey: migratedFlagKey)
    }

    private func presentWrongFileAlert() {
        let alert = NSAlert()
        alert.messageText = String(localized: .wrongFile)
        alert.informativeText = String(localized: .choosePlist)
        alert.addButton(withTitle: String(localized: .commonConfirm))
        alert.runModal()
    }

    private func presentResultAlert(success: Bool) {
        let alert = NSAlert()
        alert.messageText = success
            ? String(localized: .importSuccess)
            : String(localized: .importFail)
        alert.addButton(withTitle: String(localized: .commonConfirm))
        alert.runModal()
    }
}
