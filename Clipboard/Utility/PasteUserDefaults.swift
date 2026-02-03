//
//  PasteUserDefaults.swift
//  Clipboard
//
//  Created by crown on 2025/9/16.
//

import AppKit
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
    /// 应用启动
    @CodableUserDefaultsWrapper(
        .globalHotKeys,
        defaultValue: [
            HotKeyInfo(
                key: "app_launch",
                shortcut: KeyboardShortcut(
                    modifiersRawValue: NSEvent.ModifierFlags([
                        .command, .shift,
                    ])
                    .rawValue,
                    keyCode: KeyCode.v,
                    displayKey: "V"
                ),
                isEnabled: true,
                isGlobal: true
            ),
            HotKeyInfo(
                key: "previous_tab",
                shortcut: KeyboardShortcut(
                    modifiersRawValue: NSEvent.ModifierFlags.command.rawValue,
                    keyCode: KeyCode.leftArrow,
                    displayKey: "←"
                ),
                isEnabled: true,
                isGlobal: false
            ),
            HotKeyInfo(
                key: "next_tab",
                shortcut: KeyboardShortcut(
                    modifiersRawValue: NSEvent.ModifierFlags.command.rawValue,
                    keyCode: KeyCode.rightArrow,
                    displayKey: "→"
                ),
                isEnabled: true,
                isGlobal: false
            ),
        ]
    )
    static var globalHotKeys
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
    @CodableUserDefaultsWrapper(
        .ignoredApps,
        defaultValue: {
            var apps: [IgnoredAppInfo] = [
                IgnoredAppInfo(
                    name: "钥匙串访问",
                    bundleIdentifier: "com.apple.keychainaccess",
                    path: "/System/Applications/Utilities/Keychain Access.app"
                ),
            ]
            if #available(macOS 15.0, *) {
                apps.insert(
                    IgnoredAppInfo(
                        name: "密码",
                        bundleIdentifier: "com.apple.Passwords",
                        path: "/System/Applications/Passwords.app"
                    ),
                    at: 0
                )
            }
            return apps
        }()
    )
    static var ignoredApps

    /// 用户自定义分类
    @CodableUserDefaultsWrapper(.userCategoryChip, defaultValue: [CategoryChip]())
    static var userCategoryChip

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
    /// 粘贴时去掉末尾换行符
    @UserDefaultsWrapper(.removeTailingNewline, defaultValue: false)
    static var removeTailingNewline
    /// 背景类型(仅macOS 26+, 0:液态玻璃 1:毛玻璃)
    @UserDefaultsWrapper(.backgroundType, defaultValue: 0)
    static var backgroundType
    /// 玻璃材质强度(0-4, 默认为regular)
    @UserDefaultsWrapper(.glassMaterial, defaultValue: 2)
    static var glassMaterial
    /// tag 字段迁移标记
    @UserDefaultsWrapper(.tagFieldMigrated, defaultValue: false)
    static var tagFieldMigrated
    /// 状态栏图标
    @UserDefaultsWrapper(.showMenuBarIcon, defaultValue: true)
    static var showMenuBarIcon
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

// MARK: - Codable 属性包装器

@propertyWrapper
struct CodableUserDefaultsWrapper<T: Codable> {
    let key: PrefKey
    let defaultValue: T

    init(_ key: PrefKey, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: T {
        get {
            UserDefaults.standard.object(T.self, forKey: key.rawValue)
                ?? defaultValue
        }
        set {
            UserDefaults.standard.set(encodable: newValue, forKey: key.rawValue)
        }
    }
}

// MARK: - UserDefaults 扩展（支持 Codable）

extension UserDefaults {
    func set(encodable: (some Codable)?, forKey key: String) {
        if let data = try? JSONEncoder().encode(encodable) {
            set(data, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }

    func object<T: Codable>(_: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
