//
//  HeaderClickGestureRecognizer.swift
//  Clipboard
//
//  Created by crown on 2026/11/4
//

import AppKit

/// Keeps the existing click recognition while exposing its pressed appearance.
///
/// 按下态不依赖手势状态：AppKit 会在鼠标仍按住时 `reset()` 手势（此后不再收到 mouseUp）
/// 因此按下后改用本地事件监听跟踪拖动与松开，保证按住期间始终显示按下态
final class HeaderClickGestureRecognizer: NSClickGestureRecognizer {
    var onPressChange: ((Bool) -> Void)?
    private var pressed = false
    private var monitor: Any?

    isolated deinit {
        stopTracking()
    }

    private func setPressed(_ value: Bool) {
        guard pressed != value else { return }
        pressed = value
        onPressChange?(value)
    }

    private func startTracking() {
        stopTracking()
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            MainActor.assumeIsolated { self?.track(event) }
            return event
        }
    }

    private func stopTracking() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func track(_ event: NSEvent) {
        if event.type == .leftMouseUp {
            // 监听器早于手势收到 mouseUp：延后清除，让 action 在按下态下完成状态切换，避免闪烁
            stopTracking()
            Task { @MainActor [weak self] in self?.setPressed(false) }
            return
        }
        guard let view else { return }
        let point = view.convert(event.locationInWindow, from: nil)
        setPressed(view.bounds.contains(point))
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        setPressed(true)
        startTracking()
    }

    override func mouseUp(with event: NSEvent) {
        stopTracking()
        super.mouseUp(with: event)
        // action 执行完再清除，选中/编辑态一次绘制到位，不经过 hover 色
        setPressed(false)
    }
}
