import Foundation

/// 分页只保存原文范围和行宽，全文不进入 TextKit
nonisolated struct JSONViewportIndex: Sendable {
    struct Block: Sendable {
        var range: NSRange
        let widths: [Int: Int]

        func rows(columns: Int) -> Int {
            widths.reduce(0) { $0 + $1.value * max(1, ($1.key + columns - 1) / columns) }
        }
    }

    let blocks: [Block]
    static let blockSize = 16384

    /// 复用解析时已有的换行索引，避免再次逐字符扫描大文档
    static func build(_ source: NSString, lineStarts: [Int]) -> Self {
        var blocks: [Block] = []
        var start = 0
        var line = 0
        while start < source.length, !Task.isCancelled {
            var end = min(source.length, start + blockSize)
            var lower = line
            var upper = lineStarts.count
            while lower < upper {
                let middle = (lower + upper) / 2
                if lineStarts[middle] <= end { lower = middle + 1 } else { upper = middle }
            }
            let boundary = lineStarts[max(0, lower - 1)]
            if end < source.length {
                if boundary >= start + blockSize / 2 {
                    end = boundary
                } else {
                    let unit = source.character(at: end - 1)
                    if (0xD800...0xDBFF).contains(unit) || unit == 13 { end -= 1 }
                }
            }
            var counts: [Int: Int] = [:]
            var cursor = start
            while cursor < end {
                let next = line + 1 < lineStarts.count ? lineStarts[line + 1] : source.length
                let stop = min(end, next)
                counts[max(0, stop - cursor - (stop == next ? 1 : 0)), default: 0] += 1
                cursor = stop
                if cursor == next, line + 1 < lineStarts.count { line += 1 }
            }
            if end == source.length, lineStarts.last == source.length { counts[0, default: 0] += 1 }
            blocks.append(Block(range: NSRange(location: start, length: end - start), widths: counts))
            start = end
        }
        if blocks.isEmpty { blocks = [Block(range: NSRange(location: 0, length: 0), widths: [0: 1])] }
        return Self(blocks: blocks)
    }

    static func build(_ source: NSString, range: NSRange? = nil) -> Self {
        let range = range ?? NSRange(location: 0, length: source.length)
        var blocks: [Block] = []
        var start = range.location
        let end = NSMaxRange(range)
        var buffer = [unichar](repeating: 0, count: blockSize)
        while start < end, !Task.isCancelled {
            var length = min(blockSize, end - start)
            source.getCharacters(&buffer, range: NSRange(location: start, length: length))
            if start + length < end {
                // 优先在换行处分块；超长单行也严格限制分页大小
                if let newline = buffer.prefix(length).lastIndex(of: 10), newline >= length / 2 {
                    length = newline + 1
                } else if (0xD800...0xDBFF).contains(buffer[length - 1]) {
                    length -= 1
                } else if buffer[length - 1] == 13 {
                    length -= 1
                }
            }
            let counts = widths(in: buffer, count: length, last: start + length == end)
            blocks.append(Block(range: NSRange(location: start, length: length), widths: counts))
            start += length
        }
        if blocks.isEmpty { blocks = [Block(range: range, widths: [0: 1])] }
        return Self(blocks: blocks)
    }

    private static func widths(in buffer: [unichar], count: Int, last: Bool) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        var width = 0
        var previousCR = false
        for offset in 0..<count {
            let unit = buffer[offset]
            if unit == 10 || unit == 13 {
                if unit != 10 || !previousCR { counts[width, default: 0] += 1; width = 0 }
                previousCR = unit == 13
            } else {
                previousCR = false
                if !(0xDC00...0xDFFF).contains(unit) {
                    width += unit == 9 ? 4 : (unit >= 0x2E80 ? 2 : 1)
                }
            }
        }
        if width > 0 || last { counts[width, default: 0] += 1 }
        return counts
    }
}
