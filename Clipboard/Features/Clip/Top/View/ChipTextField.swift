import AppKit

final class ChipTextField: NSTextField {
    weak var focusRingMaskView: NSView?
    var containerCornerRadius: CGFloat = Const.radius
    var focusRingInset: CGFloat = 4
    var onFocusChange: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        (cell as? NSTextFieldCell)?.setWantsNotificationForMarkedText(true)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override var focusRingType: NSFocusRingType {
        get { .exterior }
        set {}
    }

    override var focusRingMaskBounds: NSRect {
        guard let focusRingMaskView else { return bounds }
        return focusRingMaskView.convert(
            focusRingMaskView.bounds.insetBy(
                dx: focusRingInset,
                dy: focusRingInset
            ),
            to: self
        )
    }

    override func drawFocusRingMask() {
        let maskRect = focusRingMaskBounds
        NSBezierPath(
            roundedRect: maskRect,
            xRadius: containerCornerRadius,
            yRadius: containerCornerRadius
        ).fill()
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            noteFocusRingMaskChanged()
            onFocusChange?(true)
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            onFocusChange?(false)
        }
        return result
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if isEditable {
            window?.makeFirstResponder(self)
        }
    }

    func moveCursorToEnd() {
        guard let editor = currentEditor() else { return }
        let end = editor.string.endIndex
        editor.selectedRange = NSRange(end..., in: editor.string)
    }
}
