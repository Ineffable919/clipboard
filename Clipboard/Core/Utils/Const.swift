//
//  Const.swift
//  Clipboard
//
//  Created by crown on 2025/9/27.
//

import SwiftUI

enum Const {
    static let defaultHeight: CGFloat = 330.0
    static let showDuration: CFTimeInterval = 0.15
    static let hideDuration: CFTimeInterval = 0.24

    static let cardSize: CGFloat = 235.0
    static let cntSize: CGFloat = 185.0
    static let hdSize: CGFloat = 50.0
    static let iconSize: CGFloat = 80.0

    static let cardSpace: CGFloat = 18.0
    static let cardLeadingSpace: CGFloat = 16.0
    static let bottomSize: CGFloat = 40.0

    static let windowRadis: CGFloat =
        if #available(macOS 26.0, *) {
            23.0
        } else {
            12.0
        }

    static let btnRadius: CGFloat =
        if #available(macOS 26.0, *) {
            10.0
        } else {
            6.0
        }

    static let radius: CGFloat =
        if #available(macOS 26.0, *) {
            14.0
        } else {
            8.0
        }

    static let topRadius: CGFloat =
        if #available(macOS 26.0, *) {
            18.0
        } else {
            8.0
        }

    static let settingsRadius: CGFloat = 6.0
    static let selectionBorderWidth: CGFloat = 4.0

    static let topBarHeight: CGFloat = 54.0
    static let topBarWidth: CGFloat = 450.0
    static let cardBottomPadding: CGFloat = 16.0

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

    static let maxPreviewWidth: CGFloat = 980.0
    static let maxPreviewHeight: CGFloat = 640.0
    static let maxContentHeight: CGFloat = 600.0
    static let minPreviewHeight: CGFloat = 300.0
    static let minPreviewWidth: CGFloat = 400.0
    static let maxTextheight: CGFloat = 480.0
    static let maxTextWidth: CGFloat = 660.0
    static let maxTextSize: Int = 2500

    /// 设置页面
    static let settingWidth: CGFloat = 650.0
    static let settingHeight: CGFloat = 660.0

    static let darkBackground: Color = .init(hex: "#272835")
    static let lightBackground: Color = .init(hex: "#f5f5f5")
    static let lightToolColor: Color = .init(hex: "#eeeeef")
    static let darkToolColor: Color = .init(hex: "#2e2e39")
    static let darkImageShallowColor: NSColor = .init(hex: "#383838")
    static let darkImageDeepColor: NSColor = .init(hex: "#424242")
    static let lightImageShallowColor: NSColor = .init(hex: "#ffffff")
    static let lightImageDeepColor: NSColor = .init(hex: "#f5f5f5")
    static let cardShadowColor = Color(hex: "#30689C").opacity(0.1)

    static let space32: CGFloat = 32.0
    static let space24: CGFloat = 24.0
    static let space20: CGFloat = 20.0
    static let space16: CGFloat = 16.0
    static let space14: CGFloat = 14.0
    static let space12: CGFloat = 12.0
    static let space10: CGFloat = 10.0
    static let space8: CGFloat = 8.0
    static let space6: CGFloat = 6.0
    static let space4: CGFloat = 4.0
    static let space2: CGFloat = 2.0
    static let iconSize18: CGFloat = 18.0
    static let iconSize16: CGFloat = 16.0
    static let iconSize14: CGFloat = 14.0

    static let chipPadding = EdgeInsets(
        top: space6,
        leading: space10,
        bottom: space6,
        trailing: space10
    )
}

enum FloatConst {
    static let floatWindowWidth: CGFloat = 320.0
    static let floatWindowHeight: CGFloat = 650.0
    static let cardSize: CGFloat = 300.0
    static let headerHeight: CGFloat = 90.0
    static let footerHeight: CGFloat = 32.0
    static let cardHeight: CGFloat = 60.0
    static let cardSpacing: CGFloat = 10.0
    static let floatSelectionBorderWidth: CGFloat = 2.0
}
