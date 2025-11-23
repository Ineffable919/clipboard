//
//  QuickLookPreview.swift
//  Clipboard
//
//  Created by crown on 2025/10/21.
//

import Quartz
import SwiftUI

struct QuickLookPreview: NSViewRepresentable {
    let url: URL
    var maxWidth: CGFloat?
    var maxHeight: CGFloat?

    func makeNSView(context _: Context) -> QLPreviewView {
        let previewView = QLPreviewView(frame: .zero, style: .normal)
        if let previewView {
            previewView.autoresizingMask = [.width, .height]
        }
        return previewView ?? QLPreviewView()
    }

    func updateNSView(_ nsView: QLPreviewView, context _: Context) {
        nsView.previewItem = url as QLPreviewItem

        if let maxWidth {
            nsView.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth)
                .isActive = true
        }
        if let maxHeight {
            nsView.heightAnchor.constraint(lessThanOrEqualToConstant: maxHeight)
                .isActive = true
        }
    }
}
