import AppKit

// 编辑前恢复原文，让输入法和撤销继续使用原文坐标
final class JSONTextView: NSTextView {
    var onPrepareEdit: ((NSRange) -> NSRange)?
    var onExpand: (() -> Void)?
    var onCopy: ((NSRange) -> String)?
    var onSelectAll: (() -> Void)?
    var onMove: ((Selector) -> Bool)?
    var onInputChange: (() -> Void)?
    private(set) var isHandlingInput = false

    override func scrollToVisible(_ rect: NSRect) -> Bool {
        var target = rect
        // 原生滚动会用首行的 y 坐标作为可见区域起点，需要把顶部内边距一并保留
        if target.minY > 0, target.minY <= textContainerOrigin.y {
            target.origin.y = 0
            if let scrollView = enclosingScrollView {
                target.size.height = min(target.height, scrollView.contentView.bounds.height)
            }
        }
        return super.scrollToVisible(target)
    }

    override func selectAll(_ sender: Any?) {
        if let onSelectAll { onSelectAll() } else { super.selectAll(sender) }
    }

    override func accessibilityChildren() -> [Any]? {
        // 纯文本没有附件，避免查询子元素时触发全文字体修正
        []
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        let range = onPrepareEdit?(replacementRange) ?? replacementRange
        handleInput { super.insertText(insertString, replacementRange: range) }
    }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        let range = onPrepareEdit?(replacementRange) ?? replacementRange
        handleInput { super.setMarkedText(string, selectedRange: selectedRange, replacementRange: range) }
    }

    override func unmarkText() {
        handleInput { super.unmarkText() }
    }

    private func handleInput(_ action: () -> Void) {
        let nested = isHandlingInput
        isHandlingInput = true
        action()
        isHandlingInput = nested
        if !nested { onInputChange?() }
    }

    override func doCommand(by selector: Selector) {
        if onMove?(selector) == true { return }
        let name = NSStringFromSelector(selector)
        if name.hasPrefix("delete") || name.hasPrefix("insert") || name.hasPrefix("transpose") {
            onExpand?()
        }
        super.doCommand(by: selector)
    }

    override func cut(_ sender: Any?) {
        onExpand?()
        super.cut(sender)
    }

    override func readSelection(from pasteboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        onExpand?()
        return super.readSelection(from: pasteboard, type: type)
    }

    override func writeSelection(to pasteboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        if type == .string, let onCopy {
            return pasteboard.setString(onCopy(selectedRange()), forType: .string)
        }
        return super.writeSelection(to: pasteboard, type: type)
    }

    override func performFindPanelAction(_ sender: Any?) {
        onExpand?()
        super.performFindPanelAction(sender)
    }

    override func performTextFinderAction(_ sender: Any?) {
        onExpand?()
        super.performTextFinderAction(sender)
    }
}
