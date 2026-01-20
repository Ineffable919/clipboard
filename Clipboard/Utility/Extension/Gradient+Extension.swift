//
//  Gradient+Extension.swift
//  clipboard
//
//  Created by crown on 2026/1/8.
//

import SwiftUI

extension LinearGradient {
    /// 从 hex 字符串数组创建线性渐变
    /// - Parameters:
    ///   - hexColors: hex 颜色字符串数组
    ///   - startPoint: 渐变起点，默认为 .leading
    ///   - endPoint: 渐变终点，默认为 .trailing
    /// - Returns: LinearGradient 实例
    static func fromHex(
        _ hexColors: [String],
        startPoint: UnitPoint = .leading,
        endPoint: UnitPoint = .trailing
    ) -> LinearGradient {
        let colors = hexColors.map { Color(hex: $0) }
        return LinearGradient(
            colors: colors,
            startPoint: startPoint,
            endPoint: endPoint
        )
    }

    /// 从 hex 字符串数组创建线性渐变（带渐变停止点）
    /// - Parameters:
    ///   - stops: 渐变停止点数组，每个元素为 (hex颜色, 位置)
    ///   - startPoint: 渐变起点，默认为 .leading
    ///   - endPoint: 渐变终点，默认为 .trailing
    /// - Returns: LinearGradient 实例
    static func fromHex(
        stops: [(hex: String, location: Double)],
        startPoint: UnitPoint = .leading,
        endPoint: UnitPoint = .trailing
    ) -> LinearGradient {
        let gradientStops = stops.map {
            Gradient.Stop(color: Color(hex: $0.hex), location: $0.location)
        }
        return LinearGradient(
            stops: gradientStops,
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
}

extension RadialGradient {
    /// 从 hex 字符串数组创建径向渐变
    /// - Parameters:
    ///   - hexColors: hex 颜色字符串数组
    ///   - center: 渐变中心点，默认为 .center
    ///   - startRadius: 起始半径，默认为 0
    ///   - endRadius: 结束半径，默认为 200
    /// - Returns: RadialGradient 实例
    static func fromHex(
        _ hexColors: [String],
        center: UnitPoint = .center,
        startRadius: CGFloat = 0,
        endRadius: CGFloat = 200
    ) -> RadialGradient {
        let colors = hexColors.map { Color(hex: $0) }
        return RadialGradient(
            colors: colors,
            center: center,
            startRadius: startRadius,
            endRadius: endRadius
        )
    }

    /// 从 hex 字符串数组创建径向渐变（带渐变停止点）
    /// - Parameters:
    ///   - stops: 渐变停止点数组，每个元素为 (hex颜色, 位置)
    ///   - center: 渐变中心点，默认为 .center
    ///   - startRadius: 起始半径，默认为 0
    ///   - endRadius: 结束半径，默认为 200
    /// - Returns: RadialGradient 实例
    static func fromHex(
        stops: [(hex: String, location: Double)],
        center: UnitPoint = .center,
        startRadius: CGFloat = 0,
        endRadius: CGFloat = 200
    ) -> RadialGradient {
        let gradientStops = stops.map {
            Gradient.Stop(color: Color(hex: $0.hex), location: $0.location)
        }
        return RadialGradient(
            stops: gradientStops,
            center: center,
            startRadius: startRadius,
            endRadius: endRadius
        )
    }
}

extension AngularGradient {
    /// 从 hex 字符串数组创建角度渐变
    /// - Parameters:
    ///   - hexColors: hex 颜色字符串数组
    ///   - center: 渐变中心点，默认为 .center
    ///   - startAngle: 起始角度，默认为 .zero
    ///   - endAngle: 结束角度，默认为 .degrees(360)
    /// - Returns: AngularGradient 实例
    static func fromHex(
        _ hexColors: [String],
        center: UnitPoint = .center,
        startAngle: Angle = .zero,
        endAngle: Angle = .degrees(360)
    ) -> AngularGradient {
        let colors = hexColors.map { Color(hex: $0) }
        return AngularGradient(
            colors: colors,
            center: center,
            startAngle: startAngle,
            endAngle: endAngle
        )
    }

    /// 从 hex 字符串数组创建角度渐变（带渐变停止点）
    /// - Parameters:
    ///   - stops: 渐变停止点数组，每个元素为 (hex颜色, 位置)
    ///   - center: 渐变中心点，默认为 .center
    /// - Returns: AngularGradient 实例
    static func fromHex(
        stops: [(hex: String, location: Double)],
        center: UnitPoint = .center
    ) -> AngularGradient {
        let gradientStops = stops.map {
            Gradient.Stop(color: Color(hex: $0.hex), location: $0.location)
        }
        return AngularGradient(
            stops: gradientStops,
            center: center
        )
    }
}

extension Gradient {
    /// 从 hex 字符串数组创建 Gradient
    /// - Parameter hexColors: hex 颜色字符串数组
    /// - Returns: Gradient 实例
    static func fromHex(_ hexColors: [String]) -> Gradient {
        let colors = hexColors.map { Color(hex: $0) }
        return Gradient(colors: colors)
    }

    /// 从 hex 字符串数组创建 Gradient（带渐变停止点）
    /// - Parameter stops: 渐变停止点数组，每个元素为 (hex颜色, 位置)
    /// - Returns: Gradient 实例
    static func fromHex(stops: [(hex: String, location: Double)]) -> Gradient {
        let gradientStops = stops.map {
            Gradient.Stop(color: Color(hex: $0.hex), location: $0.location)
        }
        return Gradient(stops: gradientStops)
    }
}
