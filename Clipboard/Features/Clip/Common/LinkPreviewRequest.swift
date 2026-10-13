import AppKit

@MainActor
final class LinkPreviewRequest: NSObject {
    private weak var view: NSView?
    private var requestID: UUID?
    private var operation: (@MainActor () async -> Void)?
    private var visibilityObservation: NSKeyValueObservation?

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

    @objc func updateVisibility() {
        guard isVisible else {
            cancelRequest()
            return
        }
        guard requestID == nil, let operation else { return }
        requestID = LinkPreviewQueue.shared.enqueue { [weak self] in
            guard !Task.isCancelled else { return }
            guard self?.isVisible == true else {
                self?.requestID = nil
                return
            }
            await operation()
            guard !Task.isCancelled else { return }
            // 完成后只保留视图已经显示的内容，重新显示无需再次请求
            self?.operation = nil
            self?.requestID = nil
        }
    }
}
