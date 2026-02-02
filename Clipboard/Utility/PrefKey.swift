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
    /// 显示模式（抽屉式/窗口式）
    case displayMode
    /// 窗口位置模式（中心/鼠标/上次位置）
    case windowPosition
    /// 上次窗口位置和大小
    case lastWindowFrame
}

enum AppearanceMode: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
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
            "\(n)天"
        case let .weeks(n):
            "\(n)周"
        case let .months(n):
            "\(n)个月"
        case .year:
            "1年"
        case .forever:
            "永久"
        }
    }
}

/// 背景类型(仅macOS 26+)
enum BackgroundType: Int, CaseIterable {
    case liquid = 0
    case frosted = 1

    var title: String {
        switch self {
        case .liquid: "液态玻璃"
        case .frosted: "毛玻璃"
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

    var title: String {
        switch self {
        case .drawer: "抽屉"
        case .floating: "窗口"
        }
    }
}

/// 窗口位置模式
enum WindowPositionMode: Int, CaseIterable {
    case center = 0
    case mouse = 1
    case lastPosition = 2

    var title: String {
        switch self {
        case .center: "屏幕中心"
        case .mouse: "鼠标位置"
        case .lastPosition: "上次位置"
        }
    }
}
