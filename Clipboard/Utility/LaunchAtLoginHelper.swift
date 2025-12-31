//
//  LaunchAtLoginHelper.swift
//  Clipboard
//
//  Created on crown 2025/10/28.
//

import Foundation
import ServiceManagement

final class LaunchAtLoginHelper {
    static let shared = LaunchAtLoginHelper()

    private init() {}

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
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

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
