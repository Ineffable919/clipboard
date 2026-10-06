import AppKit

/// 后台建立分页索引，原文不交给完整文档的文本系统
nonisolated final class JSONPreparedText: @unchecked Sendable {
    let source: NSString
    let index: JSONViewportIndex

    init(_ text: String, width: CGFloat, lineStarts: [Int]? = nil) {
        source = text as NSString
        index = JSONViewportIndex.build(source, lineStarts: lineStarts ?? JSONLineIndex.build(for: text))
    }

    init(source: NSString, index: JSONViewportIndex) {
        self.source = source.copy() as? NSString ?? source
        self.index = index
    }
}
