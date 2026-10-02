import AppKit

/// 滚动高度与文本控件分离，文本控件只承载当前分页
final class JSONViewportSurface: NSView {
    override var isFlipped: Bool { true }
}
