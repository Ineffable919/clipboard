//
//  BackgroundEffectController.swift
//  Clipboard
//
//  按系统版本构建窗口背景：macOS 26 及以上使用液态玻璃，其余使用毛玻璃。
//

import AppKit
import SnapKit

@MainActor
final class BackgroundEffectController {
    let effectView: NSView
    let contentContainer: NSView

    private let innerPadding: CGFloat

    init(cornerRadius: CGFloat, innerPadding: CGFloat = 0) {
        self.innerPadding = innerPadding

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        if #available(macOS 26.0, *) {
            container.layer?.cornerRadius = cornerRadius
        }
        container.layer?.masksToBounds = true
        contentContainer = container

        effectView = Self.buildEffectView(
            cornerRadius: cornerRadius,
            contentContainer: container
        )
    }

    func install(in host: NSView) {
        host.addSubview(effectView)
        effectView.snp.makeConstraints { make in
            make.leading.equalTo(innerPadding)
            make.trailing.equalTo(-innerPadding)
            make.top.equalToSuperview()
            make.bottom.equalTo(-innerPadding)
        }
        if effectView is NSVisualEffectView {
            effectView.addSubview(contentContainer)
            contentContainer.snp.makeConstraints { $0.edges.equalToSuperview() }
        }
    }

    private static func buildEffectView(
        cornerRadius: CGFloat,
        contentContainer: NSView
    ) -> NSView {
        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            glassView.cornerRadius = cornerRadius
            glassView.contentView = contentContainer
            return glassView
        }

        let visualEffect = NSVisualEffectView()
        visualEffect.wantsLayer = true
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .popover
        return visualEffect
    }
}
