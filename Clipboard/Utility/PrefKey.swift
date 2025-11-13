//
//  PrefKey.swift
//  Clipboard
//
//  Created by crown on 2025/9/16.
//

import Foundation

enum PrefKey: String {
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
}

/// 外观模式
enum AppearanceMode: Int, CaseIterable {
    case system = 0  // 跟随系统
    case light = 1  // 浅色
    case dark = 2  // 深色

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

/// 历史时间单位
enum HistoryTimeUnit: Equatable {
    case days(Int)  // 1-6 天
    case weeks(Int)  // 1-3 周
    case months(Int)  // 1-11 月
    case year  // 1 年
    case forever  // 永久

    /// 转换为原始值（用于存储）
    var rawValue: Int {
        switch self {
        case .days(let n):
            return n  // 1-6
        case .weeks(let n):
            return 6 + n  // 7-9
        case .months(let n):
            return 9 + n  // 10-20
        case .year:
            return 21
        case .forever:
            return 22
        }
    }

    /// 从原始值创建
    init(rawValue: Int) {
        switch rawValue {
        case 1...6:
            self = .days(rawValue)
        case 7...9:
            self = .weeks(rawValue - 6)
        case 10...20:
            self = .months(rawValue - 9)
        case 21:
            self = .year
        default:
            self = .forever
        }
    }

    /// 显示文本
    var displayText: String {
        switch self {
        case .days(let n):
            return "\(n)天"
        case .weeks(let n):
            return "\(n)周"
        case .months(let n):
            return "\(n)个月"
        case .year:
            return "1年"
        case .forever:
            return "永久"
        }
    }
}
