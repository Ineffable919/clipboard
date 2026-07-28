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
    let appPath: String

    private let appIconView = NSImageView()

    init(icon: NSImage?, title: String, path: String) {
        appName = title
        appPath = path
        super.init(icon: nil, title: title)
        setupAppIcon()
        updateIcon(icon)
    }

    func updateIcon(_ icon: NSImage?) {
        appIconView.image = icon
    }

    private func setupAppIcon() {
        appIconView.imageScaling = .scaleProportionallyDown
        appIconView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }
        stack.insertArrangedSubview(appIconView, at: 0)
    }
}
