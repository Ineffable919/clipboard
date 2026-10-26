//
//  CardLabelView.swift
//  Clipboard
//

import AppKit

/// A read-only label whose text is rasterized only when its presentation changes.
final class CardLabelView: CardRasterView {
    private let cell = NSTextFieldCell(textCell: "")
    private let padding: NSEdgeInsets
    private var hasAttributedContent = false

    var stringValue: String {
        get { cell.stringValue }
        set {
            guard hasAttributedContent || cell.stringValue != newValue else { return }
            hasAttributedContent = false
            cell.stringValue = newValue
            contentDidChange()
        }
    }

    var attributedStringValue: NSAttributedString {
        get { cell.attributedStringValue }
        set {
            guard !hasAttributedContent || !cell.attributedStringValue.isEqual(to: newValue) else { return }
            hasAttributedContent = true
            cell.attributedStringValue = newValue
            contentDidChange()
        }
    }

    var font: NSFont? {
        get { cell.font }
        set {
            guard cell.font != newValue else { return }
            cell.font = newValue
            contentDidChange()
        }
    }

    var textColor: NSColor? {
        get { cell.textColor }
        set {
            guard cell.textColor != newValue else { return }
            cell.textColor = newValue
            invalidateContents()
        }
    }

    var alignment: NSTextAlignment {
        get { cell.alignment }
        set {
            guard cell.alignment != newValue else { return }
            cell.alignment = newValue
            invalidateContents()
        }
    }

    var lineBreakMode: NSLineBreakMode {
        get { cell.lineBreakMode }
        set {
            guard cell.lineBreakMode != newValue else { return }
            cell.lineBreakMode = newValue
            contentDidChange()
        }
    }

    var maximumNumberOfLines: Int = 0 {
        didSet {
            guard maximumNumberOfLines != oldValue else { return }
            cell.usesSingleLineMode = maximumNumberOfLines == 1
            contentDidChange()
        }
    }

    var drawsBackground: Bool {
        get { cell.drawsBackground }
        set {
            guard cell.drawsBackground != newValue else { return }
            cell.drawsBackground = newValue
            invalidateContents()
        }
    }

    var backgroundColor: NSColor? {
        get { cell.backgroundColor }
        set {
            guard cell.backgroundColor != newValue else { return }
            cell.backgroundColor = newValue
            invalidateContents()
        }
    }

    init(padding: NSEdgeInsets = NSEdgeInsets()) {
        self.padding = padding
        super.init(frame: .zero)
        cell.isEditable = false
        cell.isSelectable = false
        cell.isBordered = false
        cell.isBezeled = false
        cell.drawsBackground = false
        cell.wraps = false
        cell.lineBreakMode = .byClipping
        cell.textColor = .labelColor
        setContentHuggingPriority(.init(251), for: .horizontal)
        setContentHuggingPriority(.defaultHigh, for: .vertical)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityValue("")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override var alignmentRectInsets: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 2, bottom: 0, right: 2)
    }

    override var intrinsicContentSize: NSSize {
        let size = cell.cellSize
        // NSTextField excludes its cell's horizontal drawing margins from its alignment size.
        return NSSize(
            width: ceil(max(0, size.width - 4)) + padding.left + padding.right,
            height: ceil(size.height) + padding.top + padding.bottom
        )
    }

    override func drawContents(in bounds: NSRect) {
        let rect = NSRect(
            x: bounds.minX + padding.left,
            y: bounds.minY + padding.top,
            width: max(0, bounds.width - padding.left - padding.right),
            height: max(0, bounds.height - padding.top - padding.bottom)
        )
        cell.draw(withFrame: rect, in: self)
    }

    override func hitTest(_: NSPoint) -> NSView? { nil }

    private func contentDidChange() {
        setAccessibilityValue(cell.stringValue)
        invalidateIntrinsicContentSize()
        invalidateContents()
    }
}
