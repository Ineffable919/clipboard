//
//  AppColorService.swift
//  Clipboard
//
//  应用图标颜色管理：提取、缓存、查询
//

import AppKit
import SwiftUI

@MainActor
final class AppColorService {
    static let shared = AppColorService()

    private static let fallbackHex = "#1765D9"

    private var colorDict: [String: String]

    private init() {
        colorDict = PasteUserDefaults.appColorData
    }

    func updateColor(for model: PasteboardModel) {
        guard colorDict[model.appName] == nil else { return }
        let iconImage = NSWorkspace.shared.icon(forFile: model.appPath)
        let hex = Self.extractHex(from: iconImage)
        colorDict[model.appName] = hex
        PasteUserDefaults.appColorData = colorDict
    }

    func color(for model: PasteboardModel) -> Color {
        if let chip = model.getGroupChip() {
            return chip.color
        }

        if let colorStr = colorDict[model.appName] {
            return Color(hex: colorStr).opacity(0.85)
        }
        return Color(hex: Self.fallbackHex).opacity(0.85)
    }
}

// MARK: - 图标主题色提取

private extension AppColorService {
    static func extractHex(from icon: NSImage) -> String {
        extractDominantColor(from: icon) ?? fallbackHex
    }

    // MARK: - 颜色分组

    enum ColorGroup {
        case red, green, blue, yellow, other
    }

    // MARK: - 主提取逻辑

    static func extractDominantColor(from image: NSImage) -> String? {
        let targetSize = CGSize(width: 32, height: 32)

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))

        guard let data = context.data else { return nil }
        let pixelData = data.bindMemory(
            to: UInt8.self,
            capacity: Int(targetSize.width * targetSize.height * 4)
        )

        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        var colorCounts: [UInt32: Float] = [:]

        for y in 0 ..< height {
            for x in 0 ..< width {
                let pixelIndex = (y * width + x) * 4
                guard Int(pixelData[pixelIndex + 3]) > 128 else { continue }

                let r = Int(pixelData[pixelIndex])
                let g = Int(pixelData[pixelIndex + 1])
                let b = Int(pixelData[pixelIndex + 2])

                guard isValidColor(r: r, g: g, b: b) else { continue }

                let key = (UInt32((r / 8) * 8) << 16)
                    | (UInt32((g / 8) * 8) << 8)
                    | UInt32((b / 8) * 8)
                colorCounts[key, default: 0] += pixelWeight(x: x, y: y, width: width, height: height)
            }
        }

        // 计算各色系权重，判断是否需要抑制暖色
        var groupWeights: [ColorGroup: Float] = [:]
        var groupCache: [UInt32: ColorGroup] = [:]

        for (color, count) in colorCounts {
            let r = Int((color >> 16) & 0xFF)
            let g = Int((color >> 8) & 0xFF)
            let b = Int(color & 0xFF)
            let group = colorGroup(r: r, g: g, b: b)
            groupCache[color] = group
            if group != .other {
                groupWeights[group, default: 0] += count
            }
        }

        let totalWeight = groupWeights.values.reduce(0, +)
        let greenBlueWeight = (groupWeights[.green] ?? 0) + (groupWeights[.blue] ?? 0)
        // 绿色和蓝色总权重超过 20% 时，认为是多彩图标，抑制红黄色
        let suppressWarmColors = totalWeight > 0 && (greenBlueWeight / totalWeight > 0.2)

        var bestColor: UInt32?
        var bestScore: Float = 0

        for (color, count) in colorCounts {
            let r = Int((color >> 16) & 0xFF)
            let g = Int((color >> 8) & 0xFF)
            let b = Int(color & 0xFF)
            var score = count * colorQuality(r: r, g: g, b: b)

            if suppressWarmColors {
                switch groupCache[color] ?? .other {
                case .red: score *= 0.1
                case .yellow: score *= 1.2
                default: break
                }
            }

            if score > bestScore {
                bestScore = score
                bestColor = color
            }
        }

        guard let dominant = bestColor else { return nil }
        let r = Int((dominant >> 16) & 0xFF)
        let g = Int((dominant >> 8) & 0xFF)
        let b = Int(dominant & 0xFF)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    // MARK: - 辅助

    static func colorGroup(r: Int, g: Int, b: Int) -> ColorGroup {
        let hue = rgbToHue(r: r, g: g, b: b)
        let saturation = rgbToSaturation(r: r, g: g, b: b)
        guard saturation >= 0.2 else { return .other }

        switch hue {
        case 330...: return .red
        case 0 ..< 30: return .red
        case 30 ..< 90: return .yellow
        case 90 ..< 180: return .green
        case 180 ..< 270: return .blue
        default: return .other
        }
    }

    static func rgbToHue(r: Int, g: Int, b: Int) -> Float {
        let R = Float(r) / 255.0
        let G = Float(g) / 255.0
        let B = Float(b) / 255.0
        let maxC = max(R, G, B)
        let minC = min(R, G, B)
        let delta = maxC - minC
        guard delta > 0 else { return 0 }

        let hue: Float = if maxC == R {
            60 * fmod((G - B) / delta, 6)
        } else if maxC == G {
            60 * (((B - R) / delta) + 2)
        } else {
            60 * (((R - G) / delta) + 4)
        }
        return hue < 0 ? hue + 360 : hue
    }

    static func rgbToSaturation(r: Int, g: Int, b: Int) -> Float {
        let R = Float(r) / 255.0
        let G = Float(g) / 255.0
        let B = Float(b) / 255.0
        let maxC = max(R, G, B)
        let minC = min(R, G, B)
        let delta = maxC - minC
        let lightness = (maxC + minC) / 2
        guard delta != 0 else { return 0 }
        return delta / (1 - abs(2 * lightness - 1))
    }

    static func isValidColor(r: Int, g: Int, b: Int) -> Bool {
        let brightness = (r + g + b) / 3
        let maxC = max(r, max(g, b))
        let saturation = maxC > 0 ? Float(maxC - min(r, min(g, b))) / Float(maxC) : 0

        if brightness < 50, saturation > 0.1 { return true }
        if brightness > 240 { return false }
        if saturation < 0.08 { return false }
        if saturation > 0.95, brightness > 180 { return false }
        return true
    }

    static func pixelWeight(x: Int, y: Int, width: Int, height: Int) -> Float {
        let centerX = Float(width) / 2.0
        let centerY = Float(height) / 2.0
        let dist = sqrt(pow(Float(x) - centerX, 2) + pow(Float(y) - centerY, 2))
        let maxDist = sqrt(pow(centerX, 2) + pow(centerY, 2))
        var weight = 1.0 + (1.0 - dist / maxDist) * 0.5

        let isNearCorner = (x < width / 4 || x >= width * 3 / 4)
            && (y < height / 4 || y >= height * 3 / 4)
        if isNearCorner { weight *= 1.3 }
        return weight
    }

    static func colorQuality(r: Int, g: Int, b: Int) -> Float {
        let maxC = max(r, max(g, b))
        let saturation = maxC > 0 ? Float(maxC - min(r, min(g, b))) / Float(maxC) : 0
        let brightness = Float(r + g + b) / 3.0
        var score: Float = 1.0

        if saturation > 0.3 { score *= 1.8 }
        else if saturation > 0.15 { score *= 1.2 }
        else if saturation < 0.1 { score *= 0.3 }

        if brightness > 30 && brightness < 230 { score *= 1.1 }
        else if brightness < 20 || brightness > 240 { score *= 0.8 }

        return score
    }
}
