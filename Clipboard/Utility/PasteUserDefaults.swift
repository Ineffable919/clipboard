//
//  PasteUserDefaults.swift
//  Clipboard
//
//  Created by crown on 2025/9/16.
//

import Foundation

// MARK: - 应用信息模型

struct IgnoredAppInfo: Codable, Hashable, Identifiable {
    let id: String // 使用 bundleIdentifier 或 path 作为 id
    let name: String
    let bundleIdentifier: String?
    let path: String

    init(name: String, bundleIdentifier: String? = nil, path: String) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        id = bundleIdentifier ?? path
    }
}

enum PasteUserDefaults {
    /// 开机自启
    @UserDefaultsWrapper(.onStart, defaultValue: false)
    static var onStart
    /// 直接粘贴
    @UserDefaultsWrapper(.pasteDirect, defaultValue: true)
    static var pasteDirect
    /// 粘贴为纯文本
    @UserDefaultsWrapper(.pasteOnlyText, defaultValue: false)
    static var pasteOnlyText
    /// 音效开关
    @UserDefaultsWrapper(.soundEnabled, defaultValue: true)
    static var soundEnabled
    /// 历史保留时间
    @UserDefaultsWrapper(.historyTime, defaultValue: 7)
    static var historyTime
    /// 本地APP颜色表
    @UserDefaultsWrapper(.appColorData, defaultValue: [String: String]())
    static var appColorData
    /// 上次清理时间
    @UserDefaultsWrapper(.lastClearDate, defaultValue: "")
    static var lastClearDate
    /// 忽略的APP
    @UserDefaultsWrapper(.ignoreList, defaultValue: [String]())
    static var ignoreList
    /// 忽略的应用程序信息
    static var ignoredApps: [IgnoredAppInfo] {
        get {
            guard
                let data = UserDefaults.standard.data(
                    forKey: PrefKey.ignoredApps.rawValue,
                )
            else {
                return [
                    IgnoredAppInfo(
                        name: "密码",
                        bundleIdentifier: "com.apple.Passwords",
                        path: "/System/Applications/Passwords.app",
                    ),
                    IgnoredAppInfo(
                        name: "钥匙串访问",
                        bundleIdentifier: "com.apple.keychainaccess",
                        path: "/System/Applications/Utilities/Keychain Access.app",
                    ),
                ]
            }
            return (try? JSONDecoder().decode([IgnoredAppInfo].self, from: data))
                ?? []
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(
                data,
                forKey: PrefKey.ignoredApps.rawValue,
            )
        }
    }

    /// 用户自定义分类
    static var userCategoryChip: [CategoryChip] {
        get {
            guard
                let data = UserDefaults.standard.data(
                    forKey: PrefKey.userCategoryChip.rawValue,
                )
            else {
                return []
            }
            return (try? JSONDecoder().decode([CategoryChip].self, from: data))
                ?? []
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(
                data,
                forKey: PrefKey.userCategoryChip.rawValue,
            )
        }
    }

    /// 删除确认
    @UserDefaultsWrapper(.delConfirm, defaultValue: false)
    static var delConfirm
    /// 屏幕共享期间显示
    @UserDefaultsWrapper(.showDuringScreenShare, defaultValue: true)
    static var showDuringScreenShare
    /// 生成链接预览
    @UserDefaultsWrapper(.enableLinkPreview, defaultValue: true)
    static var enableLinkPreview
    /// 忽略机密内容
    @UserDefaultsWrapper(.ignoreSensitiveContent, defaultValue: true)
    static var ignoreSensitiveContent
    /// 忽略瞬时内容
    @UserDefaultsWrapper(.ignoreEphemeralContent, defaultValue: true)
    static var ignoreEphemeralContent
    /// 快速粘贴修饰键 (0: Command, 1: Option, 2: Control)
    @UserDefaultsWrapper(.quickPasteModifier, defaultValue: 0)
    static var quickPasteModifier
    /// 纯文本粘贴修饰键 (0: Command, 1: Option, 2: Control, 3: Shift)
    @UserDefaultsWrapper(.plainTextModifier, defaultValue: 3)
    static var plainTextModifier
    /// 外观设置
    @UserDefaultsWrapper(.appearance, defaultValue: 0)
    static var appearance
}

@propertyWrapper
struct UserDefaultsWrapper<T> {
    let key: PrefKey
    let defaultValue: T

    init(_ key: PrefKey, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: T {
        get {
            UserDefaults.standard.object(forKey: key.rawValue) as? T
                ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key.rawValue)
        }
    }
}
