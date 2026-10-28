import AppKit
import QuartzCore

class AnimatedScrollView: NSScrollView {
    private var scrollLink: CADisplayLink? {
        didSet { updatePreviewDeferral() }
    }
    private var scrollKeys = Set<UInt16>()
    @objc dynamic private(set) var defersLinkPreviews = false
    private var lastScrollTime: CFTimeInterval?
    private var startTime: CFTimeInterval = 0
    private var duration: CFTimeInterval = 0
    private var startOrigin = NSPoint.zero
    private var targetOrigin = NSPoint.zero

    func beginKeyboardScroll(keyCode: UInt16) {
        scrollKeys.insert(keyCode)
        updatePreviewDeferral()
    }

    func endKeyboardScroll(keyCode: UInt16) {
        scrollKeys.remove(keyCode)
        updatePreviewDeferral()
    }

    func resetKeyboardScroll() {
        scrollKeys.removeAll()
        updatePreviewDeferral()
    }

    private func updatePreviewDeferral() {
        let deferred = !scrollKeys.isEmpty || scrollLink != nil
        guard defersLinkPreviews != deferred else { return }
        defersLinkPreviews = deferred
    }

    func scroll(to origin: NSPoint, animated: Bool, isKeyRepeat: Bool = false) {
        let current = contentView.bounds.origin
        guard animated else {
            stopScrolling()
            apply(origin)
            return
        }
        guard origin != current else { return }

        let now = CACurrentMediaTime()
        let interval = min(lastScrollTime.map { now - $0 } ?? 0.25, 0.25)
        lastScrollTime = now
        duration = !isKeyRepeat && interval > 0.1 ? interval : 0
        startTime = now
        startOrigin = current
        targetOrigin = origin

        if scrollLink == nil {
            let link = displayLink(target: self, selector: #selector(updateScroll(_:)))
            scrollLink = link
            link.add(to: .main, forMode: .common)
        }
    }

    func stopScrolling() {
        scrollLink?.invalidate()
        scrollLink = nil
        lastScrollTime = nil
    }

    override func scrollWheel(with event: NSEvent) {
        stopScrolling()
        super.scrollWheel(with: event)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            stopScrolling()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    @objc private func updateScroll(_ link: CADisplayLink) {
        let progress = duration > 0
            ? min(max((CACurrentMediaTime() - startTime) / duration, 0), 1)
            : 1
        if progress >= 1 {
            apply(targetOrigin)
            link.invalidate()
            scrollLink = nil
            return
        }

        let eased = Self.ease(progress, tolerance: max(duration * 0.005, 0.0001))
        apply(NSPoint(
            x: startOrigin.x + (targetOrigin.x - startOrigin.x) * eased,
            y: startOrigin.y + (targetOrigin.y - startOrigin.y) * eased
        ))
    }

    private func apply(_ origin: NSPoint) {
        var bounds = contentView.bounds
        bounds.origin = origin
        let constrained = contentView.constrainBoundsRect(bounds)
        let aligned = contentView.backingAlignedRect(constrained, options: [.alignAllEdgesNearest])
        // 避免 AppKit 再次对齐小数坐标，重复触发位置通知和布局
        guard aligned.origin != contentView.bounds.origin else { return }
        contentView.setBoundsOrigin(aligned.origin)
        reflectScrolledClipView(contentView)
    }

    // cubic-bezier(0.25, 0.1, 0.25, 1)：先反解横坐标，再求纵坐标
    private static func ease(_ progress: Double, tolerance: Double) -> Double {
        var lower = 0.0
        var upper = 1.0
        var parameter = progress
        for _ in 0 ..< 20 {
            let position = parameter * (0.75 + parameter * (-0.75 + parameter))
            if abs(position - progress) <= tolerance { break }
            if position < progress {
                lower = parameter
            } else {
                upper = parameter
            }
            parameter = (lower + upper) / 2
        }
        return parameter * (0.3 + parameter * (2.4 - 1.7 * parameter))
    }
}
