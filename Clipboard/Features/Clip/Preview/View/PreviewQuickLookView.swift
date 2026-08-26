//
//  PreviewQuickLookView.swift
//  Clipboard
//
//  Quick Look 文件预览。
//

import AppKit
import Quartz
import SnapKit

final class PreviewQuickLookView: NSView, PreviewResettable {
    private var quickLookView: QLPreviewView?

    init(filePath: String) {
        super.init(frame: .zero)
        wantsLayer = true

        let url = URL(fileURLWithPath: filePath)

        guard let preview = QLPreviewView(frame: .zero, style: .normal) else {
            showFallbackIcon(for: url)
            return
        }

        preview.autoresizingMask = [.width, .height]
        preview.previewItem = url as QLPreviewItem
        quickLookView = preview

        addSubview(preview)
        preview.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func resetPreview() {
        quickLookView?.previewItem = nil
        quickLookView?.removeFromSuperview()
        quickLookView = nil
    }

    private func showFallbackIcon(for url: URL) {
        let icon = NSWorkspace.shared.icon(forFile: url.path())
        let imageView = NSImageView()
        imageView.image = icon
        imageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(128)
        }
    }
}
