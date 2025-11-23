//
//  LaunchAtLoginHelper.swift
//  Clipboard
//
//  Created on 2025/10/28.
//

import Foundation
import ServiceManagement

final class LaunchAtLoginHelper {
    static let shared = LaunchAtLoginHelper()

    private init() {}

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            setEnabledModern(enabled)
        } else {
            setEnabledLegacy(enabled)
        }
    }

    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            isEnabledModern
        } else {
            isEnabledLegacy
        }
    }

    // MARK: - macOS 13.0+ 实现

    @available(macOS 13.0, *)
    private func setEnabledModern(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            log.error("设置开机自启动失败: \(error.localizedDescription)")
            return false
        }
    }

    @available(macOS 13.0, *)
    private var isEnabledModern: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @available(macOS, deprecated: 13.0)
    private func setEnabledLegacy(_ enabled: Bool) -> Bool {
        let success: Bool = if enabled {
            SMLoginItemSetEnabled(
                "com.crown.clipboard" as CFString,
                true,
            )
        } else {
            SMLoginItemSetEnabled(
                "com.crown.clipboard" as CFString,
                false,
            )
        }

        if success {
            log.debug("开机自启动设置成功: \(enabled)")
        } else {
            log.warn("开机自启动设置失败")
        }

        return success
    }

    @available(macOS, deprecated: 13.0)
    private var isEnabledLegacy: Bool {
        PasteUserDefaults.onStart
    }
}
