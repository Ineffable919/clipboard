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

    func makeNSView(context _: Context) -> QLPreviewView {
        return QLPreviewView(frame: .zero, style: .normal)
    }

    func updateNSView(_ nsView: QLPreviewView, context _: Context) {
        nsView.previewItem = url as QLPreviewItem
    }
}
