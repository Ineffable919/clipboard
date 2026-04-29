//
//  SearchSuggestionWindow.swift
//  Clipboard
//
//  联想列表窗口
//

import AppKit

final class SearchSuggestionWindow: NSPanel {
    // MARK: - Metrics

    private enum Metrics {
        static let minWidth: CGFloat = 125
        static let cornerRadius: CGFloat = 12
        static let verticalGap: CGFloat = 4
        /// icon + padding + gap 的固定宽度
        static let rowFixedWidth: CGFloat = 8 + 18 + 6 + 8
    }

    // MARK: - Properties

    let suggestionVC = SearchSuggestionViewController()

    // MARK: - Views

    private let effectView: NSVisualEffectView = {
        let ev = NSVisualEffectView()
        ev.material = .popover
        ev.state = .active
        ev.blendingMode = .behindWindow
        ev.wantsLayer = true
        ev.layer?.cornerRadius = Metrics.cornerRadius
        ev.layer?.masksToBounds = true
        return ev
    }()

    // MARK: - Init

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true

        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = Metrics.cornerRadius
        container.layer?.masksToBounds = true
        contentView = container

        container.addSubview(effectView)
        effectView.frame = container.bounds
        effectView.autoresizingMask = [.width, .height]

        suggestionVC.loadView()
        effectView.addSubview(suggestionVC.view)
        suggestionVC.view.frame = effectView.bounds
        suggestionVC.view.autoresizingMask = [.width, .height]
    }

    // MARK: - Show / Hide / Update

    func show(at cursorScreenOrigin: NSPoint, items: [SearchSuggestionItem], parentWindow: NSWindow) {
        let width = calculateWidth(for: items)
        let height = suggestionVC.preferredHeight
        let frame = calculateFrame(
            cursorScreenOrigin: cursorScreenOrigin,
            width: width,
            height: height
        )

        setFrame(frame, display: true)
        parentWindow.addChildWindow(self, ordered: .above)
        orderFront(nil)
    }

    func updateFrame(at cursorScreenOrigin: NSPoint, items: [SearchSuggestionItem]) {
        let width = calculateWidth(for: items)
        let height = suggestionVC.preferredHeight
        let frame = calculateFrame(
            cursorScreenOrigin: cursorScreenOrigin,
            width: width,
            height: height
        )
        setFrame(frame, display: true)
    }

    func hide() {
        parent?.removeChildWindow(self)
        orderOut(nil)
    }

    // MARK: - Mouse Events

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            suggestionVC.handleClick(at: event.locationInWindow)
            return
        }
        super.sendEvent(event)
    }

    // MARK: - Key Handling

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    // MARK: - Private

    private func calculateWidth(for items: [SearchSuggestionItem]) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 12)
        var maxTextWidth: CGFloat = 0

        for item in items {
            let textWidth = (item.title as NSString).size(withAttributes: [.font: font]).width
            maxTextWidth = max(maxTextWidth, textWidth)
        }

        let totalWidth = ceil(Metrics.rowFixedWidth + maxTextWidth)
        return max(totalWidth, Metrics.minWidth)
    }

    private func calculateFrame(
        cursorScreenOrigin: NSPoint,
        width: CGFloat,
        height: CGFloat
    ) -> NSRect {
        // 窗口出现在光标正下方
        NSRect(
            x: cursorScreenOrigin.x,
            y: cursorScreenOrigin.y - height - Metrics.verticalGap,
            width: width,
            height: height
        )
    }
}
