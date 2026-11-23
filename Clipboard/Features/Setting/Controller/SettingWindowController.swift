//
//  SettingWindowController.swift
//  Clipboard
//
//  Created by crown on 2025/10/26
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
                .titled, .closable, .miniaturizable, .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        window.level = .normal
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.contentViewController = Self.makeContentController(viewModel: viewModel)
        window.setContentSize(NSSize(width: Const.settingWidth, height: Const.settingHeight))
        window.center()
        if #available(macOS 26.0, *) {
            // 需带工具栏布局，侧边栏才会顶到窗口顶部；透明标题栏须在布局之后再设
            window.toolbar = NSToolbar()
            window.toolbarStyle = .unified
            window.layoutIfNeeded()
        }
        window.titlebarAppearsTransparent = true

        super.init(window: window)
        updateWindowTitle()

        window.onCommandW = { [weak self] in
            self?.hideWindow()
        }

        window.onCommandM = { [weak self] in
            self?.minWindow()
        }
    }

    static func makeContentController(viewModel: SettingViewModel) -> NSSplitViewController {
        let sidebar = NSHostingController(rootView: SettingSidebarView().environment(viewModel))
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = sidebarItem.minimumThickness
        sidebarItem.canCollapse = false

        let detail = NSHostingController(rootView: SettingDetailView().environment(viewModel))
        detail.sizingOptions = .minSize
        detail.safeAreaRegions = []

        let controller = NSSplitViewController()
        controller.splitView.isVertical = true
        controller.splitView.dividerStyle = .thin
        controller.addSplitViewItem(sidebarItem)
        controller.addSplitViewItem(NSSplitViewItem(viewController: detail))
        return controller
    }

    private func updateWindowTitle() {
        withObservationTracking {
            window?.title = String(localized: viewModel.selectedPage.title)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateWindowTitle()
            }
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
