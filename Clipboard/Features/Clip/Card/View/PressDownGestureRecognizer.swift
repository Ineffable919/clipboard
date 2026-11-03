import AppKit

/// 鼠标按下即识别，不等待抬起
final class PressDownGestureRecognizer: NSGestureRecognizer {
    override func mouseDown(with _: NSEvent) {
        state = .ended
    }
}
