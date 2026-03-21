//
//  PrefKey.swift
//  Clipboard
//
//  Created by crown on 2025/9/16.
//

import Foundation
import SwiftUI

enum PrefKey: String, CaseIterable {
    /// 开机自启
    case onStart
    /// 直接粘贴
    case pasteDirect
    /// 粘贴为纯文本
    case pasteOnlyText
    /// 音效开关
    case soundEnabled
    /// 历史容量时间
    case historyTime
    /// 本地APP颜色表
    case appColorData
    /// 上次清理时间
    case lastClearDate
    /// 忽略的APP
    case ignoreList
    /// 忽略的应用程序信息
    case ignoredApps
    /// 用户自定义分类
    case userCategoryChip
    /// 删除确认
    case delConfirm
    /// 屏幕共享期间显示
    case showDuringScreenShare
    /// 生成链接预览
    case enableLinkPreview
    /// 忽略机密内容
    case ignoreSensitiveContent
    /// 忽略瞬时内容
    case ignoreEphemeralContent
    /// 快速粘贴修饰键
    case quickPasteModifier
    /// 纯文本粘贴修饰键
    case plainTextModifier
    /// 外观设置
    case appearance
    /// 快捷键
    case globalHotKeys
    /// 粘贴时去掉末尾换行符
    case removeTailingNewline
    /// 背景类型(仅macOS 26+)
    case backgroundType
    /// 玻璃材质强度
    case glassMaterial
    /// tag 字段迁移标记
    case tagFieldMigrated
    /// hidden 字段新增标记
    case hiddenFieldMigrated
    /// 显示模式（抽屉式/窗口式）
    case displayMode
    /// 窗口位置模式（中心/鼠标/上次位置）
    case windowPosition
    /// 上次窗口位置和大小
    case lastWindowFrame
    /// 显示状态栏图标
    case showMenuBarIcon
    /// 显示 Dock 图标
    case showDockIcon
    /// 应用语言
    case appLanguage
}

/// 应用语言
enum AppLanguage: String, CaseIterable, Identifiable {
    case zhHans = "zh-Hans"
    case english = "en"

    var id: String {
        rawValue
    }

    var title: LocalizedStringResource {
        switch self {
        case .zhHans: .settingLanguageOptionSimplifiedChinese
        case .english: .settingLanguageOptionEnglish
        }
    }

    func apply() -> Bool {
        UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        return true
    }
}

enum AppearanceMode: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2

    var title: LocalizedStringResource {
        switch self {
        case .system: .settingAppearanceModeSystem
        case .light: .settingAppearanceModeLight
        case .dark: .settingAppearanceModeDark
        }
    }
}

/// 历史时间单位
enum HistoryTimeUnit: Equatable {
    case days(Int) // 1-6 天
    case weeks(Int) // 1-3 周
    case months(Int) // 1-11 月
    case year // 1 年
    case forever // 永久

    var rawValue: Int {
        switch self {
        case let .days(n):
            n // 1-6
        case let .weeks(n):
            6 + n // 7-9
        case let .months(n):
            9 + n // 10-20
        case .year:
            21
        case .forever:
            22
        }
    }

    init(rawValue: Int) {
        switch rawValue {
        case 1 ... 6:
            self = .days(rawValue)
        case 7 ... 9:
            self = .weeks(rawValue - 6)
        case 10 ... 20:
            self = .months(rawValue - 9)
        case 21:
            self = .year
        default:
            self = .forever
        }
    }

    var displayText: String {
        switch self {
        case let .days(n):
            String.localizedStringWithFormat(String(localized: "historyTimeDisplayDays", defaultValue: "%lld days", table: "Localizable"), n)
        case let .weeks(n):
            String.localizedStringWithFormat(String(localized: "historyTimeDisplayWeeks", defaultValue: "%lld weeks", table: "Localizable"), n)
        case let .months(n):
            String.localizedStringWithFormat(String(localized: "historyTimeDisplayMonths", defaultValue: "%lld months", table: "Localizable"), n)
        case .year:
            String(localized: .historyTimeDisplayYear)
        case .forever:
            String(localized: .historyTimeDisplayForever)
        }
    }
}

/// 背景类型(仅macOS 26+)
enum BackgroundType: Int, CaseIterable {
    case liquid = 0
    case frosted = 1

    var title: LocalizedStringResource {
        switch self {
        case .liquid: .settingAppearanceBackgroundTypeLiquid
        case .frosted: .settingAppearanceBackgroundTypeFrosted
        }
    }
}

/// 玻璃材质强度
enum GlassMaterial: Int, CaseIterable {
    case ultraThin = 0
    case thin = 1
    case regular = 2
    case thick = 3
    case ultraThick = 4

    var material: Material {
        switch self {
        case .ultraThin: .ultraThinMaterial
        case .thin: .thinMaterial
        case .regular: .regularMaterial
        case .thick: .thickMaterial
        case .ultraThick: .ultraThickMaterial
        }
    }
}

/// 显示模式
enum DisplayMode: Int, CaseIterable {
    case drawer = 0
    case floating = 1

    var title: LocalizedStringResource {
        switch self {
        case .drawer: .settingAppearanceDisplayModeDrawer
        case .floating: .settingAppearanceDisplayModeWindow
        }
    }
}

/// 窗口位置模式
enum WindowPositionMode: Int, CaseIterable {
    case center = 0
    case mouse = 1
    case lastPosition = 2

    var title: LocalizedStringResource {
        switch self {
        case .center: .settingAppearanceWindowPositionCenter
        case .mouse: .settingAppearanceWindowPositionMouse
        case .lastPosition: .settingAppearanceWindowPositionLast
        }
    }
}
