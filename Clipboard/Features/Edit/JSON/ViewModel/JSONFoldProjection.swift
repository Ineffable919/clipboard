import Foundation

/// 映射原文与折叠显示的范围，保留嵌套节点的折叠状态
struct JSONFoldProjection {
    struct Segment {
        let source: NSRange
        let display: NSRange
    }

    private(set) var nodes: [JSONFoldIndex.Node] = []
    private(set) var collapsed: Set<Int> = []
    private(set) var segments: [Segment] = []

    mutating func reset(nodes: [JSONFoldIndex.Node] = []) {
        self.nodes = nodes
        collapsed.removeAll()
        segments.removeAll()
    }

    func node(atLineStart location: Int) -> Int? {
        var lower = 0
        var upper = nodes.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if nodes[middle].lineStart < location {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower < nodes.count && nodes[lower].lineStart == location ? lower : nil
    }

    mutating func toggle(_ node: Int) {
        if collapsed.contains(node) {
            collapsed.remove(node)
        } else {
            collapsed.insert(node)
        }
        segments.removeAll(keepingCapacity: true)
        var removed = 0
        for index in collapsed.sorted() {
            let body = nodes[index].body
            if let previous = segments.last, body.location < NSMaxRange(previous.source) {
                continue
            }
            segments.append(Segment(
                source: body,
                display: NSRange(location: body.location - removed, length: 3)
            ))
            removed += body.length - 3
        }
    }

    func sourceLocation(for location: Int, trailing: Bool = false) -> Int {
        guard let segment = preceding(location, key: \.display) else { return location }
        if location < NSMaxRange(segment.display) {
            return trailing ? NSMaxRange(segment.source) : segment.source.location
        }
        return location + NSMaxRange(segment.source) - NSMaxRange(segment.display)
    }

    func sourceRange(for range: NSRange) -> NSRange {
        let start = sourceLocation(for: range.location)
        let end = sourceLocation(for: NSMaxRange(range), trailing: range.length > 0)
        return NSRange(location: start, length: max(0, end - start))
    }

    func displayLocation(for location: Int) -> Int {
        guard let segment = preceding(location, key: \.source) else { return location }
        if location < NSMaxRange(segment.source) {
            return segment.display.location
        }
        return location - NSMaxRange(segment.source) + NSMaxRange(segment.display)
    }

    func displayRange(for range: NSRange) -> NSRange {
        let start = displayLocation(for: range.location)
        let end = displayLocation(for: NSMaxRange(range))
        return NSRange(location: start, length: max(0, end - start))
    }

    func text(in source: NSString, range: NSRange) -> String {
        if segments.isEmpty {
            return source.substring(with: range)
        }
        var output = ""
        var location = range.location
        for segment in segments where segment.source.location >= range.location
            && NSMaxRange(segment.source) <= NSMaxRange(range) {
            output += source.substring(with: NSRange(location: location, length: segment.source.location - location))
            output += " … "
            location = NSMaxRange(segment.source)
        }
        output += source.substring(with: NSRange(location: location, length: NSMaxRange(range) - location))
        return output
    }

    private func preceding(_ location: Int, key: KeyPath<Segment, NSRange>) -> Segment? {
        var lower = 0
        var upper = segments.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if segments[middle][keyPath: key].location <= location {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower > 0 ? segments[lower - 1] : nil
    }
}
