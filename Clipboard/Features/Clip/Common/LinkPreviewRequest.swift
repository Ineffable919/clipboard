import AppKit

@MainActor
final class LinkPreviewRequest: NSObject {
    private weak var view: NSView?
    private var requestID: UUID?
    private var operation: (@MainActor () async -> Void)?
    private var visibilityObservation: NSKeyValueObservation?
    private var scrollObservation: NSKeyValueObservation?

    init(view: NSView) {
        self.view = view
        super.init()
    }

    isolated deinit {
        cancel()
        NotificationCenter.default.removeObserver(self)
    }

    func load(_ operation: @escaping @MainActor () async -> Void) {
        cancel()
        self.operation = operation
        updateVisibility()
    }

    func cancel() {
        cancelRequest()
        operation = nil
    }

    private func cancelRequest() {
        if let requestID { LinkPreviewQueue.shared.cancel(requestID) }
        requestID = nil
    }

    func viewDidMoveToWindow() {
        let center = NotificationCenter.default
        center.removeObserver(self)
        visibilityObservation = view?.window?.observe(\.isVisible, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.updateVisibility()
            }
        }
        scrollObservation = (view?.enclosingScrollView as? AnimatedScrollView)?
            .observe(\.defersLinkPreviews, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.updateVisibility()
                }
            }
        if let clipView = view?.enclosingScrollView?.contentView {
            center.addObserver(self, selector: #selector(updateVisibility),
                               name: NSView.boundsDidChangeNotification, object: clipView)
        }
        updateVisibility()
    }

    private var isVisible: Bool {
        guard let view else { return false }
        return view.window?.isVisible == true && view.bounds.intersects(view.visibleRect)
    }

    private var canStart: Bool {
        isVisible && (view?.enclosingScrollView as? AnimatedScrollView)?.defersLinkPreviews != true
    }

    @objc func updateVisibility() {
        guard isVisible else {
            cancelRequest()
            return
        }
        guard canStart, requestID == nil, let operation else { return }
        requestID = LinkPreviewQueue.shared.enqueue { [weak self] in
            guard !Task.isCancelled else { return }
            // 排队期间可能开始了键盘滚动，实际执行前再次检查。
            guard self?.canStart == true else {
                self?.requestID = nil
                return
            }
            await operation()
            guard !Task.isCancelled else { return }
            self?.operation = nil
            self?.requestID = nil
        }
    }
}
