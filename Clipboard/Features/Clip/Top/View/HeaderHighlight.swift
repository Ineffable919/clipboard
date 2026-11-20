//
//  HeaderHighlight.swift
//  Clipboard
//
//  Created by crown on 2026/11/4
//

import AppKit

/// 主面板头部（Chip / 图标按钮）共用的高亮背景色
enum HeaderHighlight {
    case none, hover, selected, pressed

    var alpha: CGFloat {
        switch self {
        case .none: 0
        case .hover: 0.05
        case .selected: 0.10
        case .pressed: 0.15
        }
    }

    func color(isDark: Bool) -> NSColor {
        (isDark ? NSColor.white : .black).withAlphaComponent(alpha)
    }
}

/// 头部控件所处的外观场景
enum HeaderStyle {
    /// 浮动面板（沿用原有样式）
    case floating
    /// 主面板（统一的黑/白透明度高亮）
    case mainPanel
}
