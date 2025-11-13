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

    /// 设置开机自启动
    /// - Parameter enabled: true 启用，false 禁用
    /// - Returns: 操作是否成功
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            return setEnabledModern(enabled)
        } else {
            return setEnabledLegacy(enabled)
        }
    }

    /// 检查是否已启用开机自启动
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return isEnabledModern
        } else {
            return isEnabledLegacy
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
        return SMAppService.mainApp.status == .enabled
    }

    // MARK: - macOS 13.0 以下的实现

    @available(macOS, deprecated: 13.0)
    private func setEnabledLegacy(_ enabled: Bool) -> Bool {
        let success: Bool
        if enabled {
            success = SMLoginItemSetEnabled(
                "cn.crown.Clipboard" as CFString,
                true
            )
        } else {
            success = SMLoginItemSetEnabled(
                "cn.crown.Clipboard" as CFString,
                false
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
        return PasteUserDefaults.onStart
    }
}
