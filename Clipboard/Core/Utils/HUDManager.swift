//
//  HUDManager.swift
//  Clipboard
//
//  Created by crown on 2026/4/27.
//

import AppKit
import SnapKit
import SwiftUI

// MARK: - HUDManager

@MainActor
final class HUDManager {
    static let shared = HUDManager()
    private init() {}

    private var hudWindow: HUDWindow?
    private var dismissTask: Task<Void, Never>?

    func show(
        icon: NSImage? = NSImage(systemSymbolName: "hammer.fill", accessibilityDescription: nil),
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

        if #available(macOS 26.0, *) {
            window.setGlassContent(icon: icon, text: text)
        } else if let targetView = window.contentTarget {
            buildContent(in: targetView, icon: icon, text: text)
        }

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
                make.centerY.equalToSuperview().offset(-16)
                make.size.equalTo(100)
            }
        }

        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .preferredFont(forTextStyle: .title1)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0

        parent.addSubview(label)
        label.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(26)
            make.leading.equalToSuperview().inset(16)
            make.trailing.equalToSuperview().inset(16)
        }
    }

    func centerWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        let originX = screenFrame.midX - windowFrame.width / 2
        let originY = screenFrame.origin.y + 60 - HUDWindow.effectPadding
        window.setFrameOrigin(NSPoint(x: originX, y: originY))
    }
}

// MARK: - HUDWindow

@MainActor
private final class HUDWindow: NSPanel {
    // HUD-only private API: keep the glass active without making the panel key.
    @objc(_hasActiveAppearanceIgnoringKeyFocus)
    dynamic func hasActiveAppearanceIgnoringKeyFocus() -> Bool {
        true
    }

    private static let hudSize = CGSize(width: 200, height: 200)
    private static let cornerRadius: CGFloat = 26
    static var effectPadding: CGFloat {
        if #available(macOS 26.0, *) {
            HUDContentView.effectPadding
        } else {
            24
        }
    }

    private(set) var contentTarget: NSView?

    init() {
        super.init(
            contentRect: NSRect(
                origin: .zero,
                size: CGSize(
                    width: Self.hudSize.width + Self.effectPadding * 2,
                    height: Self.hudSize.height + Self.effectPadding * 2
                )
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovable = false

        if #available(macOS 26.0, *) {
            // SwiftUI's glass provides its own shadow inside the transparent window.
            hasShadow = false
            return
        }

        let host = NSView(frame: NSRect(origin: .zero, size: frame.size))
        contentView = host
        let background = makeVisualEffectView()
        contentTarget = background
        host.addSubview(background)
        background.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Self.effectPadding)
        }
    }

    // MARK: Background

    @available(macOS 26.0, *)
    func setGlassContent(icon: NSImage?, text: String) {
        let rootView = HUDContentView(icon: icon, text: text, size: Self.hudSize)
        if let hosting = contentView as? NSHostingView<HUDContentView> {
            hosting.rootView = rootView
        } else {
            let hosting = NSHostingView(rootView: rootView)
            hosting.sizingOptions = []
            contentView = hosting
        }
    }

    private func makeVisualEffectView() -> NSVisualEffectView {
        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.hudSize))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = Self.cornerRadius
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true
        return effect
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
