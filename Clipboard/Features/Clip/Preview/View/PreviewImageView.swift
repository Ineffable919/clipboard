//
//  PreviewImageView.swift
//  Clipboard
//
//  图片及实况文本预览。
//

import AppKit
import SnapKit

final class PreviewImageView: NSView, PreviewResettable {
    private let liveTextView: PreviewLiveTextView

    init(model: PasteboardModel, maxContentH: CGFloat = Const.maxTextheight) {
        liveTextView = PreviewLiveTextView(imageData: model.data)
        super.init(frame: .zero)
        wantsLayer = true

        let checker = CheckerboardView()
        addSubview(checker)
        checker.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(liveTextView)

        if let size = model.cachedImageSize, size.width > 0, size.height > 0 {
            let availableW = Const.maxPreviewWidth - Const.space12 * 2
            let scale = min(availableW / size.width, maxContentH / size.height, 1.0)
            let displayW = ceil(size.width * scale)
            let displayH = ceil(size.height * scale)
            liveTextView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.equalTo(displayW)
                make.height.equalTo(displayH)
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
