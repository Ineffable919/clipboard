//
//  ClipboardEmptyStateView.swift
//  Clipboard
//
//  Created by crown on 2026/2/12.
//

import SwiftUI

/// A view that displays an empty state when there is no clipboard history.
///
/// This view adapts its appearance based on the display style (main window or floating window).
struct ClipboardEmptyStateView: View {
    enum Style {
        case main
        case floating
    }

    let style: Style

    private var iconSize: CGFloat {
        style == .main ? 64 : 48
    }

    var body: some View {
        VStack(spacing: Const.space12) {
            clipboardIcon
                .font(.system(size: iconSize))
                .foregroundStyle(Color.accentColor.opacity(0.8))

            Text("没有剪贴板历史")
                .foregroundStyle(.secondary)

            Text("复制内容后将显示在这里")
                .font(style == .floating ? .system(size: 13) : .callout)
                .foregroundStyle(.secondary)
        }
        .padding(style == .main ? .all : [])
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var clipboardIcon: some View {
        if #available(macOS 26.0, *) {
            Image(systemName: "sparkle.text.clipboard")
        } else {
            Image("sparkle.text.clipboard")
        }
    }
}
