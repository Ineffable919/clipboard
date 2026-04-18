//
//  SettingWindowController.swift
//  Clipboard
//
//  Created on crown 2025/10/26.
//

import AppKit
import SwiftUI

class SettingWindowController: NSWindowController {
    static let shared = SettingWindowController()
    private let viewModel = SettingViewModel()

    private init() {
        let window = SettingWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Const.settingWidth,
                height: Const.settingHeight
            ),
            styleMask: [
                .titled, .closable, .miniaturizable, .fullSizeContentView,
            ],
            backing: .buffered,
            defer: false
        )

        window.level = .normal
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarSeparatorStyle = .none
        window.titlebarAppearsTransparent = true

        let settingView = SettingView()
            .environment(viewModel)
        window.contentView = NSHostingView(rootView: settingView)

        super.init(window: window)

        window.onCommandW = { [weak self] in
            self?.hideWindow()
        }

        window.onCommandM = { [weak self] in
            self?.minWindow()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggleWindow() {
        guard let window else { return }

        NSApp.activate(ignoringOtherApps: true)

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        window.makeKeyAndOrderFront(nil)
    }

    func toggleWindow(page: SettingPage) {
        viewModel.navigateTo(page)
        toggleWindow()
    }

    func hideWindow() {
        window?.orderOut(nil)
    }

    func minWindow() {
        guard let window else { return }

        if window.isVisible, !window.isMiniaturized {
            window.miniaturize(nil)
        }
    }
}
