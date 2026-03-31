//
//  CardTextView.swift
//  Clipboard
//
//  Created by crown on 2026/3/31.
//

import AppKit
import SwiftUI

struct CardTextView: NSViewRepresentable {
    let attributedString: NSAttributedString
    var isSelectable: Bool = false

    func makeNSView(context _: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = isSelectable
        textView.drawsBackground = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.layoutManager?.allowsNonContiguousLayout = true
        return textView
    }

    func updateNSView(_ textView: NSTextView, context _: Context) {
        textView.isSelectable = isSelectable
        textView.textStorage?.setAttributedString(attributedString)
    }
}
