//
//  AppFilterButton.swift
//  Clipboard
//
//  应用筛选按钮：带应用图标的 FilterButton 子类
//

import AppKit
import SnapKit

final class AppFilterButton: FilterButton {
    let appName: String

    init(icon: NSImage?, title: String) {
        appName = title
        super.init(icon: nil, title: title)

        if let appIcon = icon {
            setupAppIcon(appIcon)
        }
    }

    private func setupAppIcon(_ icon: NSImage) {
        let iconView = NSImageView()
        iconView.image = icon
        iconView.imageScaling = .scaleProportionallyDown
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }
        stack.insertArrangedSubview(iconView, at: 0)
    }
}
