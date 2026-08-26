//
//  PreviewFileView.swift
//  Clipboard
//
//  单文件或多文件预览入口。
//

import AppKit
import SnapKit

final class PreviewFileView: NSView, PreviewResettable {
    private var previewContentView: (NSView & PreviewResettable)?

    init(model: PasteboardModel) {
        super.init(frame: .zero)
        wantsLayer = true

        if let paths = model.cachedFilePaths, !paths.isEmpty {
            if paths.count == 1, let first = paths.first {
                let quickLookView = PreviewQuickLookView(filePath: first)
                previewContentView = quickLookView
                addSubview(quickLookView)
                quickLookView.snp.makeConstraints { $0.edges.equalToSuperview() }
            } else {
                let multiView = PreviewMultiFileView(filePaths: paths)
                addSubview(multiView)
                multiView.snp.makeConstraints { $0.edges.equalToSuperview() }
            }
        } else {
            let imageView = NSImageView()
            imageView.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
            imageView.contentTintColor = NSColor.controlAccentColor.withAlphaComponent(0.8)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.height.equalTo(80)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func resetPreview() {
        previewContentView?.resetPreview()
        previewContentView = nil
    }
}
