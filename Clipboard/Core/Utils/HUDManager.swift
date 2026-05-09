//
//  HUDManager.swift
//  Clipboard
//
//  Created by crown on 2026/4/27.
//

import AppKit
import SnapKit

// MARK: - HUDManager

@MainActor
final class HUDManager {
    static let shared = HUDManager()
    private init() {}

    private var hudWindow: HUDWindow?
    private var dismissTask: Task<Void, Never>?

    private var contentTarget: NSView? {
        hudWindow?.contentTarget
    }

    func show(
        icon: NSImage? = NSImage(systemSymbolName: "hammer", accessibilityDescription: nil),
        text: String = String(localized: "hudCopySucceeded"),
        duration: TimeInterval = 1.5
    ) {
        presentHUD(icon: icon, text: text, duration: duration)
    }

    func dismiss() {
        fadeOutAndClose()
    }
}

// MARK: - Private

private extension HUDManager {
    func presentHUD(icon: NSImage?, text: String, duration: TimeInterval) {
        let window: HUDWindow
        if let existing = hudWindow {
            window = existing
        } else {
            window = HUDWindow()
            hudWindow = window
        }

        guard let targetView = contentTarget else { return }
        buildContent(in: targetView, icon: icon, text: text)

        centerWindow(window)

        dismissTask?.cancel()
        dismissTask = nil

        window.alphaValue = 0
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.fadeOutAndClose()
        }
    }

    func fadeOutAndClose() {
        dismissTask?.cancel()
        dismissTask = nil

        guard let window = hudWindow else { return }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                window.orderOut(nil)
                self?.hudWindow = nil
            }
        }
    }

    func buildContent(in parent: NSView, icon: NSImage?, text: String) {
        parent.subviews.forEach { $0.removeFromSuperview() }

        if let icon {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 100, weight: .regular)
            let scaledIcon = icon.withSymbolConfiguration(symbolConfig) ?? icon

            let imageView = NSImageView(frame: .zero)
            imageView.image = scaledIcon
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.contentTintColor = .secondaryLabelColor

            parent.addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.centerY.equalToSuperview().offset(-18)
                make.size.equalTo(120)
            }
        }

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: NSFont.systemFontSize + 5, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2

        parent.addSubview(label)
        label.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(20)
            make.leading.greaterThanOrEqualToSuperview().inset(12)
            make.trailing.lessThanOrEqualToSuperview().inset(12)
        }
    }

    func centerWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let wf = window.frame
        let x = sf.midX - wf.width / 2
        let y = sf.origin.y + 60
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - HUDWindow

@MainActor
private final class HUDWindow: NSPanel {
    private static let hudSize = CGSize(width: 200, height: 200)
    private static let cornerRadius: CGFloat = 20

    private(set) var contentTarget: NSView?

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.hudSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovable = false

        contentView = makeBackgroundView()
    }

    // MARK: Background

    private func makeBackgroundView() -> NSView {
        if #available(macOS 26.0, *) {
            return makeGlassView()
        } else {
            let ve = makeVisualEffectView()
            contentTarget = ve
            return ve
        }
    }

    @available(macOS 26.0, *)
    private func makeGlassView() -> NSView {
        let glass = NSGlassEffectView()
        glass.frame = NSRect(origin: .zero, size: Self.hudSize)
        glass.cornerRadius = Self.cornerRadius

        let container = NSView()
        container.wantsLayer = true
        glass.contentView = container
        contentTarget = container

        return glass
    }

    private func makeVisualEffectView() -> NSVisualEffectView {
        let ve = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.hudSize))
        ve.material = .hudWindow
        ve.blendingMode = .behindWindow
        ve.state = .active
        ve.wantsLayer = true
        ve.layer?.cornerRadius = Self.cornerRadius
        ve.layer?.cornerCurve = .continuous
        ve.layer?.masksToBounds = true
        return ve
    }
}

// MARK: - Convenience Extensions

extension HUDManager {
    func showCopySucceeded() {
        let img = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        show(icon: img, text: String(localized: "hudCopySucceeded"))
    }

    func showPasteSucceeded() {
        let img = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        show(icon: img, text: String(localized: "hudPasteSucceeded"))
    }
}
