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

    static let cardSpace: CGFloat = 20.0
    static let bottomSize: CGFloat = 40.0

    static let radius: CGFloat =
        if #available(macOS 26.0, *) {
            14.0
        } else {
            8.0
        }

    static let settingsRadius: CGFloat = 12.0

    static let topBarHeight: CGFloat = 52.0
    static let topBarWidth: CGFloat = 280.0
    static let cardBottomPadding: CGFloat = 16.0
    static let iconHdSize: CGFloat = 16.0

    static let hoverDarkColor: Color = .init(NSColor(hex: "#2e2e39"))
    static let hoverLightColorLiquid: Color = .init(NSColor(hex: "#E1E4E7"))
        .opacity(0.6)
    static let hoverLightColorFrosted: Color = .white.opacity(0.6)
    static let hoverLightColorFrostedLow: Color = .init(nsColor: NSColor(hex: "#D0D0CF")).opacity(0.6)

    static let chooseDarkColor: Color = .init(NSColor(hex: "#2e2e39"))
    static let chooseLightColorLiquid: Color = .init(NSColor(hex: "#E1E4E7"))
    static let chooseLightColorFrosted: Color = .white.opacity(0.8)
    static let chooseLightColorFrostedLow: Color = .init(nsColor: NSColor(hex: "#D0D0CF"))

    static let contentShape = UnevenRoundedRectangle(
        topLeadingRadius: 0,
        bottomLeadingRadius: Const.radius,
        bottomTrailingRadius: Const.radius,
        topTrailingRadius: 0,
        style: .continuous,
    )

    static let headShape = UnevenRoundedRectangle(
        topLeadingRadius: Const.radius,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: 0,
        topTrailingRadius: Const.radius,
        style: .continuous,
    )

    static let maxPreviewWidth: CGFloat = 800.0
    static let maxPreviewHeight: CGFloat = 600.0
    static let maxContentHeight: CGFloat = 480.0
    static let minPreviewHeight: CGFloat = 300.0
    static let minPreviewWidth: CGFloat = 400.0
    static let maxTextSize: Int = 20000
    static let maxRichTextSize: Int = 2000

    /// 设置页面
    static let settingWidth: CGFloat = 640.0
    static let settingHeight: CGFloat = 640.0

    static let darkBackground: Color = .init(NSColor(hex: "#272835"))
    static let lightBackground: Color = .init(NSColor(hex: "#f8f8f8"))
    static let lightToolColor: Color = .init(NSColor(hex: "#eeeeef"))
    static let darkToolColor: Color = .init(NSColor(hex: "#2e2e39"))

    static let space32: CGFloat = 32.0
    static let space24: CGFloat = 24.0
    static let space16: CGFloat = 16.0
    static let space12: CGFloat = 12.0
    static let space10: CGFloat = 10.0
    static let space8: CGFloat = 8.0
    static let space6: CGFloat = 6.0
    static let space4: CGFloat = 4.0
    static let iconSize18: CGFloat = 18.0
}
