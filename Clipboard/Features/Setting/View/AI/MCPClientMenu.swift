//
//  MCPClientMenu.swift
//  Clipboard
//
//  Created by crown on 2026/11/13
//

import AppKit
import SwiftUI

/// 「连接工具」下拉菜单
///
/// macOS 27 起 `NSMenuItem` 的图片默认由系统决定是否显示（`.automatic`），
/// SwiftUI `Menu` 无法覆盖，因此用 `NSPopUpButton` 并把菜单项设为 `.visible`
struct MCPClientMenu: NSViewRepresentable {
    let title: String
    let clients: [MCPClientInfo]
    let onSelect: (MCPClientInfo) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: true)
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.clients = clients
        context.coordinator.onSelect = onSelect

        button.removeAllItems()
        // 下拉模式下第一项作为按钮标题
        button.addItem(withTitle: title)
        for (index, client) in clients.enumerated() {
            let item = NSMenuItem(
                title: client.name,
                action: #selector(Coordinator.pick(_:)),
                keyEquivalent: ""
            )
            item.target = context.coordinator
            item.tag = index
            item.image = Self.menuIcon(named: client.icon)
            if #available(macOS 27.0, *) {
                item.preferredImageVisibility = .visible
            }
            button.menu?.addItem(item)
        }
    }

    func sizeThatFits(
        _: ProposedViewSize,
        nsView: NSPopUpButton,
        context _: Context
    ) -> CGSize? {
        nsView.intrinsicContentSize
    }

    /// NSMenu 不会缩放大图，需预先绘制成 16pt，并裁成圆角以统一方形底图标的外观
    private static func menuIcon(named name: String) -> NSImage? {
        guard let source = NSImage(named: name) else { return nil }
        return NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).addClip()
            source.draw(in: rect)
            return true
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var clients: [MCPClientInfo] = []
        var onSelect: (MCPClientInfo) -> Void = { _ in }

        @objc func pick(_ sender: NSMenuItem) {
            guard clients.indices.contains(sender.tag) else { return }
            onSelect(clients[sender.tag])
        }
    }
}
