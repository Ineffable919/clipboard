import AppKit

/// 优先明显主导色，再比较中心位置、局部对比和多处分布，最后应用色系偏好
enum AppIconColorExtractor {
    private static let pixelSize = 32
    private static let mergeDistance: Double = 48
    private static let gridSize = 8
    private static let scoreTolerance = 0.75

    static func extract(from image: NSImage) -> String? {
        let pixels = samples(from: image)
        if let neutral = neutralBackground(from: pixels) { return neutral }
        var candidates = clusters(from: pixels.filter { $0.isSuitable })
        if candidates.isEmpty {
            candidates = clusters(from: pixels.filter { $0.brightness > 30 && $0.brightness < 230 })
        }
        candidates = candidates.filter { $0.regionCount > 0 }
        guard !candidates.isEmpty else { return nil }
        let totalArea = candidates.reduce(0) { $0 + $1.area }
        let ranked = candidates.sorted {
            if $0.area != $1.area { return $0.area > $1.area }
            return $0.rgbKey < $1.rgbKey
        }
        let leader = ranked[0]
        let nextRegionCount = ranked.dropFirst().map(\.regionCount).max() ?? 0
        // 主导色必须同时具备足够面积和分布优势，避免局部色块压过全图主色
        let isDominant = leader.area >= totalArea * 0.45
            && Double(leader.regionCount) >= Double(nextRegionCount) * 1.4
        let highestScore = candidates.map(\.visualScore).max() ?? 0
        let finalists = isDominant ? [leader] : candidates.filter {
            // 高对比也不能让微小装饰色抢走主色；中心主体允许分布范围略小
            $0.area >= totalArea * 0.1
                && ($0.visualScore >= highestScore * scoreTolerance
                    || ($0.centrality >= 0.6 && $0.area >= totalArea * 0.12))
        }
        let selected = finalists.sorted { lhs, rhs in
            if lhs.colorPriority != rhs.colorPriority { return lhs.colorPriority > rhs.colorPriority }
            if lhs.visualScore != rhs.visualScore { return lhs.visualScore > rhs.visualScore }
            if lhs.area != rhs.area { return lhs.area > rhs.area }
            return lhs.rgbKey < rhs.rgbKey
        }.first
        guard let selected else { return nil }
        // 色系合并只决定谁胜出；输出该色系中面积最大的相近色簇，避免渐变混成新色
        let shades = clusters(from: pixels.filter {
            $0.isSuitable && $0.colorPriority == selected.colorPriority
        }, mergeFamilies: false)
        let representative = shades.sorted {
            if $0.area != $1.area { return $0.area > $1.area }
            return $0.rgbKey < $1.rgbKey
        }.first ?? selected
        let hex = String(representative.rgbKey, radix: 16, uppercase: true)
        return "#" + String(repeating: "0", count: 6 - hex.count) + hex
    }

    private static func samples(from image: NSImage) -> [ColorArea] {
        guard let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: pixelSize, height: pixelSize, bitsPerComponent: 8,
                  bytesPerRow: pixelSize * 4, space: space,
                  bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return [] }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
        guard let data = context.data else { return [] }
        let pixels = data.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * pixelSize)
        var buckets: [UInt32: ColorArea] = [:]
        for row in 0 ..< pixelSize {
            for column in 0 ..< pixelSize {
                let offset = row * context.bytesPerRow + column * 4
                let alpha = Double(pixels[offset + 3])
                guard alpha > 128 else { continue }
                let red = min(255, Double(pixels[offset]) * 255 / alpha)
                let green = min(255, Double(pixels[offset + 1]) * 255 / alpha)
                let blue = min(255, Double(pixels[offset + 2]) * 255 / alpha)
                let key = (UInt32(red / 8) << 16) | (UInt32(green / 8) << 8) | UInt32(blue / 8)
                var sample = ColorArea(red: red, green: green, blue: blue, area: alpha / 255)
                let center = Double(pixelSize) / 2
                let distance = max(abs(Double(column) + 0.5 - center), abs(Double(row) + 0.5 - center)) / center
                sample.centerWeight = sample.area * (1 - distance)
                sample.contrastWeight = sample.area * localContrast(
                    of: sample, row: row, column: column, pixels: pixels
                )
                let cellSize = pixelSize / gridSize
                let region = (row / cellSize) * gridSize + column / cellSize
                sample.regionAreas[region] = sample.area
                if var bucket = buckets[key] {
                    bucket.merge(sample)
                    buckets[key] = bucket
                } else {
                    buckets[key] = sample
                }
            }
        }
        // 先按桶键排序，再稳定地按面积排序，避免字典遍历顺序影响聚类
        return buckets.keys.sorted().compactMap { buckets[$0] }.sorted {
            if $0.area != $1.area { return $0.area > $1.area }
            return $0.rgbKey < $1.rgbKey
        }
    }

    /// 只比较附近有效彩色像素，黑白文字和透明边缘不制造虚假的颜色对比
    private static func localContrast(
        of sample: ColorArea, row: Int, column: Int, pixels: UnsafeMutablePointer<UInt8>
    ) -> Double {
        var total = 0.0
        var count = 0.0
        for (deltaRow, deltaColumn) in [(-4, 0), (4, 0), (0, -4), (0, 4)] {
            let nextRow = row + deltaRow
            let nextColumn = column + deltaColumn
            guard (0 ..< pixelSize).contains(nextRow), (0 ..< pixelSize).contains(nextColumn) else { continue }
            let offset = (nextRow * pixelSize + nextColumn) * 4
            let alpha = Double(pixels[offset + 3])
            guard alpha > 128 else { continue }
            let neighbor = ColorArea(
                red: min(255, Double(pixels[offset]) * 255 / alpha),
                green: min(255, Double(pixels[offset + 1]) * 255 / alpha),
                blue: min(255, Double(pixels[offset + 2]) * 255 / alpha), area: 1
            )
            guard neighbor.isSuitable else { continue }
            total += sample.squaredDistance(to: neighbor).squareRoot() / (255 * Double(3).squareRoot())
            count += 1
        }
        return count > 0 ? total / count : 0
    }

    private static func clusters(from samples: [ColorArea], mergeFamilies: Bool = true) -> [ColorArea] {
        var groups: [ColorArea] = []
        for sample in samples {
            var nearest: Int?
            var distance = mergeDistance * mergeDistance
            for index in groups.indices {
                let group = groups[index]
                // 同色系的渐变共同统计，避免粉紫、深浅蓝被分成多个竞争者
                let sameFamily = mergeFamilies && group.saturation >= 0.2 && sample.saturation >= 0.2
                    && group.colorPriority == sample.colorPriority
                let candidate = sameFamily ? 0 : group.squaredDistance(to: sample)
                if candidate < distance {
                    nearest = index
                    distance = candidate
                }
            }
            if let nearest {
                groups[nearest].merge(sample)
            } else {
                groups.append(sample)
            }
        }
        return groups
    }

    private struct ColorArea {
        var red: Double
        var green: Double
        var blue: Double
        var area: Double
        var centerWeight: Double = 0
        var centrality: Double { centerWeight / area }
        var contrastWeight: Double = 0
        // 范围采用平方根，避免单纯面积压过多处重复出现的醒目色块
        var visualScore: Double {
            let contrast = contrastWeight / area
            // 低对比的渐变碎块不额外加分；明显对比的重复色块最多获得三倍权重
            let prominence = min(1, max(0, (contrast - 0.15) / 0.1))
            return Double(regionCount).squareRoot() * (0.5 + centrality)
                * (1 + contrast) * (1 + 2 * separation * prominence)
        }

        /// 八邻域连接色块；忽略微小碎片，只奖励有足够面积且相隔较远的两块颜色
        var separation: Double {
            var remaining = Set(regionAreas.indices.filter { regionAreas[$0] >= 1.6 })
            var components: [(area: Double, center: CGPoint)] = []
            while let start = remaining.min() {
                remaining.remove(start)
                var pending = [start]
                var weight = 0.0
                var horizontal = 0.0
                var vertical = 0.0
                while let index = pending.popLast() {
                    let row = index / gridSize
                    let column = index % gridSize
                    weight += regionAreas[index]
                    horizontal += Double(column) * regionAreas[index]
                    vertical += Double(row) * regionAreas[index]
                    for next in remaining.sorted() where abs(next / gridSize - row) <= 1
                        && abs(next % gridSize - column) <= 1 {
                        remaining.remove(next)
                        pending.append(next)
                    }
                }
                if weight >= max(8, area * 0.15) {
                    components.append((weight, CGPoint(x: horizontal / weight, y: vertical / weight)))
                }
            }
            var result = 0.0
            for first in components.indices {
                for second in components.indices where second > first {
                    let lhs = components[first]
                    let rhs = components[second]
                    let distance = hypot(lhs.center.x - rhs.center.x, lhs.center.y - rhs.center.y)
                        / Double(gridSize - 1)
                    let balance = min(lhs.area, rhs.area) / max(lhs.area, rhs.area)
                    result = max(result, min(1, distance) * balance.squareRoot())
                }
            }
            return result
        }
        var regionAreas = [Double](repeating: 0, count: gridSize * gridSize)

        var regionCount: Int {
            let cellSize = pixelSize / gridSize
            let minimumArea = Double(cellSize * cellSize) * 0.1
            return regionAreas.filter { $0 >= minimumArea }.count
        }

        var rgbKey: UInt32 {
            (UInt32(red.rounded()) << 16) | (UInt32(green.rounded()) << 8) | UInt32(blue.rounded())
        }

        var brightness: Double { (red + green + blue) / 3 }

        var saturation: Double {
            let maximum = max(red, green, blue)
            return maximum > 0 ? (maximum - min(red, green, blue)) / maximum : 0
        }

        var hue: Double {
            let maximum = max(red, green, blue)
            let delta = maximum - min(red, green, blue)
            guard delta > 0 else { return 0 }
            let value: Double
            if maximum == red {
                value = 60 * ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if maximum == green {
                value = 60 * ((blue - red) / delta + 2)
            } else {
                value = 60 * ((red - green) / delta + 4)
            }
            return value < 0 ? value + 360 : value
        }

        var isSuitable: Bool {
            return brightness > 30 && brightness <= 240 && saturation >= 0.08
                && !(saturation > 0.95 && brightness > 180)
        }

        mutating func merge(_ other: ColorArea) {
            let total = area + other.area
            red = (red * area + other.red * other.area) / total
            green = (green * area + other.green * other.area) / total
            blue = (blue * area + other.blue * other.area) / total
            centerWeight += other.centerWeight
            contrastWeight += other.contrastWeight
            area = total
            for index in regionAreas.indices { regionAreas[index] += other.regionAreas[index] }
        }

        func squaredDistance(to other: ColorArea) -> Double {
            let deltaRed = red - other.red
            let deltaGreen = green - other.green
            let deltaBlue = blue - other.blue
            return deltaRed * deltaRed + deltaGreen * deltaGreen + deltaBlue * deltaBlue
        }

        // 分布得分接近时：蓝 > 黄/橙 > 绿 > 其他 > 红
        var colorPriority: Int {
            guard saturation >= 0.2 else { return 1 }
            switch hue {
            case 180 ..< 250: return 4
            case 20 ..< 90: return 3
            case 90 ..< 180: return 2
            case 0 ..< 20, 330...: return 0
            default: return 1
            }
        }

    }
}

extension AppIconColorExtractor {
    private static func neutralBackground(from pixels: [ColorArea]) -> String? {
        let total = pixels.reduce(0) { $0 + $1.area }
        guard total > 0 else { return nil }
        let colorful = pixels.filter { $0.saturation >= 0.4 && $0.brightness > 50 }
            .reduce(0) { $0 + $1.area }
        guard colorful / total < 0.15 else { return nil }
        let dark = pixels.filter { $0.saturation < 0.4 && $0.brightness < 90 }
            .reduce(0) { $0 + $1.area }
        return dark / total >= 0.55 ? "#061335" : nil
    }

}
