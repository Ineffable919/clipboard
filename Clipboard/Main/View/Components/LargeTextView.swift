//
//  LargeTextView.swift
//  Clipboard
//
//  Created by crown on 2025/12/05.
//

import AppKit
import SwiftUI

struct LargeTextView: NSViewRepresentable {
    let model: PasteboardModel

    func makeNSView(context _: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true

        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = .labelColor

        textView.layoutManager?.allowsNonContiguousLayout = true

        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context _: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if model.pasteboardType.isText() {
            if model.pasteboardType == .string {
                textView.backgroundColor = .controlBackgroundColor
                if let text = String(data: model.data, encoding: .utf8) {
                    textView.string = text
                    textView.font = .systemFont(ofSize: NSFont.systemFontSize)
                    textView.textColor = .labelColor
                }
            } else {
                // 富文本 (RTF/RTFD)
                if model.hasBgColor {
                    let bgColor = NSColor(model.backgroundColor)
                    textView.backgroundColor = bgColor
                    if let attributedString = NSAttributedString(
                        with: model.data,
                        type: model.pasteboardType
                    ) {
                        textView.textStorage?.setAttributedString(attributedString)
                    }
                } else {
                    textView.backgroundColor = .controlBackgroundColor
                    if let attributedString = NSAttributedString(
                        with: model.data,
                        type: model.pasteboardType
                    ) {
                        textView.string = attributedString.string
                        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
                        textView.textColor = .labelColor
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let testModel = PasteboardModel(
        pasteboardType: .string,
        data: String(repeating: "这是测试文本内容。\n", count: 100).data(using: .utf8) ?? Data(),
        showData: nil,
        timestamp: Int64(Date().timeIntervalSince1970),
        appPath: "",
        appName: "Preview",
        searchText: "",
        length: 1000,
        group: -1,
        tag: "string"
    )

    LargeTextView(model: testModel)
        .frame(width: Const.maxPreviewWidth, height: Const.maxPreviewHeight)
}
