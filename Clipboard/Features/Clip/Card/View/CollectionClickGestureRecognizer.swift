import AppKit

final class CollectionClickGestureRecognizer: NSClickGestureRecognizer {
    private(set) var clickModifiers: NSEvent.ModifierFlags = []

    override func mouseDown(with event: NSEvent) {
        clickModifiers = event.modifierFlags
        super.mouseDown(with: event)
    }

    // 与列表原生的选择和拖动手势同时识别
    override func canPrevent(_: NSGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by _: NSGestureRecognizer) -> Bool {
        false
    }
}
