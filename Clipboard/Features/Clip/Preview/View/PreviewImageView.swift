//
//  PreviewImageView.swift
//  Clipboard
//
//  Created by crown on 2026/8/26
//
//  图片及实况文本预览
//

import AppKit
import SnapKit

final class PreviewImageView: NSView, PreviewResettable {
    private let liveTextView: PreviewLiveTextView

    private static func displaySize(for model: PasteboardModel, maxContentH: CGFloat) -> CGSize? {
        guard let size = model.cachedImageSize, size.width > 0, size.height > 0 else { return nil }
        let availableW = Const.maxPreviewWidth - Const.space12 * 2
        let scale = min(availableW / size.width, maxContentH / size.height, 1.0)
        return CGSize(width: ceil(size.width * scale), height: ceil(size.height * scale))
    }

    init(model: PasteboardModel, maxContentH: CGFloat = Const.maxTextheight) {
        let displaySize = Self.displaySize(for: model, maxContentH: maxContentH)
        // 按显示尺寸降采样，避免每次打开都解码原图
        let scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
        let side = displaySize.map { max($0.width, $0.height) } ?? Const.maxPreviewWidth
        liveTextView = PreviewLiveTextView(model: model, maxPixelSize: Int((side * scale).rounded(.up)))
        super.init(frame: .zero)
        wantsLayer = true

        let checker = CheckerboardView()
        addSubview(checker)
        checker.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(liveTextView)

        if let displaySize {
            liveTextView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.equalTo(displaySize.width)
                make.height.equalTo(displaySize.height)
                make.leading.greaterThanOrEqualToSuperview()
                make.trailing.lessThanOrEqualToSuperview()
                make.top.greaterThanOrEqualToSuperview()
                make.bottom.lessThanOrEqualToSuperview()
            }
        } else {
            liveTextView.snp.makeConstraints { $0.edges.equalToSuperview() }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func resetPreview() {
        liveTextView.resetPreview()
    }
}
