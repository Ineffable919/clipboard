//
//  Const.swift
//  Clipboard
//
//  Created by crown on 2025/9/27.
//

import SwiftUI

class Const {
    static let cardSize: CGFloat = 235.0
    static let cntSize: CGFloat = 185.0
    static let hdSize: CGFloat = 50.0
    static let iconSize: CGFloat = 80.0
    static let emptySize: CGFloat = {
        if #available(macOS 26.0, *) {
            return 272.0
        } else {
            return 255.0
        }
    }()
    static let cardSpace: CGFloat = 20.0
    static let bottomSize: CGFloat = 40.0
    static let space: CGFloat = 8.0
    static let radius: CGFloat = {
        if #available(macOS 26.0, *) {
            return 12.0
        } else {
            return 8.0
        }
    }()
    static let topBarHeight: CGFloat = 48.0
    static let topBarWidth: CGFloat = 280.0
    static let cardBottomPadding: CGFloat = 16.0
    static let iconHdSize: CGFloat = 18.0

    static let hoverColor: Color = Color.gray.opacity(0.2)
    static let chooseColor: Color = Color.gray.opacity(0.2)
    static let contentShape = UnevenRoundedRectangle(
        topLeadingRadius: 0,
        bottomLeadingRadius: Const.radius,
        bottomTrailingRadius: Const.radius,
        topTrailingRadius: 0,
        style: .continuous
    )

    static let headShape = UnevenRoundedRectangle(
        topLeadingRadius: Const.radius,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: 0,
        topTrailingRadius: Const.radius,
        style: .continuous
    )

    static let maxPreviewSize: CGFloat = 800.0
    static let maxPreviewHeight: CGFloat = 480.0
    static let maxTextSize: Int = 20000
    static let maxRichTextSize: Int = 5000

    /// 设置页面
    static let settingWidth: CGFloat = 640.0
    static let settingHeight: CGFloat = 640.0

    static let darkBackground: Color = Color(NSColor(hex: "#272835"))
    static let lightBackground: Color = Color(NSColor(hex: "#f8f8f8"))
    static let lightToolColor: Color = Color(NSColor(hex: "#eeeeef"))
    static let darkToolColor: Color = Color(NSColor(hex: "#2e2e39"))
}
