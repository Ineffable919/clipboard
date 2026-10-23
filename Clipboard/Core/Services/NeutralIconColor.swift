import AppKit

/// 处理没有有效彩色候选的图标，背景或主体不可靠时交回原取色流程
nonisolated enum NeutralIconColor {
    private static let alphaThreshold = 128.0 / 255

    private struct Pixel {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
        var brightness: Double { (red + green + blue) / 3 }
    }

    static func extract(from context: CGContext) -> String? {
        guard let data = context.data else { return nil }
        let size = context.width
        let bytes = data.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * context.height)
        var pixels: [Pixel] = []
        pixels.reserveCapacity(size * size)
        for row in 0..<size {
            for column in 0..<size {
                let offset = row * context.bytesPerRow + column * 4
                let alpha = Double(bytes[offset + 3])
                let divisor = max(1, alpha)
                pixels.append(Pixel(
                    red: min(255, Double(bytes[offset]) * 255 / divisor),
                    green: min(255, Double(bytes[offset + 1]) * 255 / divisor),
                    blue: min(255, Double(bytes[offset + 2]) * 255 / divisor), alpha: alpha / 255
                ))
            }
        }
        guard let background = background(in: pixels, size: size),
              background >= 160 || background <= 96 else { return nil }
        let opaque = pixels.filter { $0.alpha > alphaThreshold }.count
        if background <= 96 {
            return darkBackground(in: pixels, brightness: background, opaque: opaque, size: size)
        }
        let mask = pixels.map {
            $0.alpha > alphaThreshold && $0.brightness <= background - 64
        }
        let count = mask.filter { $0 }.count
        guard count >= max(6, opaque / 50), count <= opaque * 2 / 3,
              let subject = subject(in: mask, pixels: pixels, size: size, minimum: max(6, opaque / 100))
        else { return nil }
        return representative(in: subject, pixels: pixels, mask: mask, size: size)
    }

    /// 暗底必须占据至少一半可见区域，取连贯且颜色稳定的底板，忽略少量亮字和高光
    private static func darkBackground(in pixels: [Pixel], brightness: Double, opaque: Int, size: Int) -> String? {
        let mask = pixels.map {
            $0.alpha > alphaThreshold && $0.brightness <= 96 && abs($0.brightness - brightness) <= 32
        }
        let minimum = max(6, (opaque + 1) / 2)
        guard let base = subject(in: mask, pixels: pixels, size: size, minimum: minimum) else { return nil }
        return representative(in: base, pixels: pixels, mask: mask, size: size)
    }

    private static func background(in pixels: [Pixel], size: Int) -> Double? {
        var histogram = [Double](repeating: 0, count: 256)
        var total = 0.0
        for row in 0..<size {
            for column in 0..<size where row < 5 || column < 5 || row >= size - 5 || column >= size - 5 {
                let pixel = pixels[row * size + column]
                guard pixel.alpha > alphaThreshold else { continue }
                histogram[Int(pixel.brightness.rounded())] += pixel.alpha
                total += pixel.alpha
            }
        }
        guard total >= Double(size) else { return nil }
        var sum = 0.0
        var best = 0.0
        var start = 0
        for value in 0..<256 {
            sum += histogram[value]
            if value >= 49 { sum -= histogram[value - 49] }
            if sum > best { best = sum; start = max(0, value - 48) }
        }
        guard best >= total * 0.6 else { return nil }
        let weighted = (start...min(255, start + 48)).reduce(0.0) { $0 + Double($1) * histogram[$1] }
        return weighted / best
    }

    private static func subject(in mask: [Bool], pixels: [Pixel], size: Int, minimum: Int) -> [Int]? {
        var visited = [Bool](repeating: false, count: mask.count)
        var best: [Int]?
        var bestScore = 0.0
        for start in mask.indices where mask[start] && !visited[start] {
            var pending = [start]
            var component: [Int] = []
            var score = 0.0
            visited[start] = true
            while let index = pending.popLast() {
                component.append(index)
                let row = index / size
                let column = index % size
                let center = Double(size) / 2
                let distance = max(abs(Double(row) + 0.5 - center), abs(Double(column) + 0.5 - center)) / center
                score += pixels[index].alpha * (1.5 - distance)
                for nextRow in max(0, row - 1)...min(size - 1, row + 1) {
                    for nextColumn in max(0, column - 1)...min(size - 1, column + 1) {
                        let next = nextRow * size + nextColumn
                        if mask[next] && !visited[next] {
                            visited[next] = true
                            pending.append(next)
                        }
                    }
                }
            }
            if component.count >= minimum, score > bestScore { best = component; bestScore = score }
        }
        return best
    }

    private static func representative(in subject: [Int], pixels: [Pixel], mask: [Bool], size: Int) -> String? {
        var histogram = [Double](repeating: 0, count: 256)
        var total = 0.0
        for index in subject {
            let pixel = pixels[index]
            let row = index / size
            let column = index % size
            var similar = 0
            for nextRow in max(0, row - 1)...min(size - 1, row + 1) {
                for nextColumn in max(0, column - 1)...min(size - 1, column + 1) {
                    let next = nextRow * size + nextColumn
                    if next != index, mask[next], abs(pixels[next].brightness - pixel.brightness) <= 32 {
                        similar += 1
                    }
                }
            }
            guard similar >= 2 else { continue }
            let weight = pixel.alpha * Double(similar * similar) / 64
            histogram[Int(pixel.brightness.rounded())] += weight
            total += weight
        }
        guard total >= max(0.5, Double(subject.count) * 0.05) else { return nil }
        var cumulative = 0.0
        let median = histogram.indices.first { cumulative += histogram[$0]; return cumulative >= total / 2 } ?? 0
        let index = subject.min {
            let lhs = abs(pixels[$0].brightness - Double(median))
            let rhs = abs(pixels[$1].brightness - Double(median))
            return lhs == rhs ? $0 < $1 : lhs < rhs
        }
        guard let index else { return nil }
        let pixel = pixels[index]
        let rgb = (UInt32(pixel.red.rounded()) << 16)
            | (UInt32(pixel.green.rounded()) << 8) | UInt32(pixel.blue.rounded())
        let hex = String(rgb, radix: 16, uppercase: true)
        return "#" + String(repeating: "0", count: 6 - hex.count) + hex
    }
}
