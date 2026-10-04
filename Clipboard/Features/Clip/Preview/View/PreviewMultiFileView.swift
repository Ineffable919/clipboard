//
//  PreviewMultiFileView.swift
//  Clipboard
//
//  多文件图标堆叠预览。
//

import AppKit
import SnapKit

final class PreviewMultiFileView: NSView {
    init(filePaths: [String]) {
        super.init(frame: .zero)
        wantsLayer = true

        let paths = Array(filePaths.prefix(4))
        let thumbnailSize: CGFloat = 320

        for (index, path) in paths.enumerated().reversed() {
            let url = URL(fileURLWithPath: path)
            let icon = NSWorkspace.shared.icon(forFile: url.path())
            let imageView = NSImageView()
            imageView.image = icon
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = Const.radius
            imageView.layer?.masksToBounds = true

            addSubview(imageView)
            let xOffset = CGFloat(index) * 20
            let yOffset = CGFloat(index) * 10
            imageView.snp.makeConstraints { make in
                make.width.height.equalTo(thumbnailSize)
                make.centerX.equalToSuperview().offset(xOffset - Const.space32)
                make.centerY.equalToSuperview().offset(-yOffset)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}
