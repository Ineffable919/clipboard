//
//  WindowManager.swift
//  Clipboard
//
//  Created by crown on 2025/1/14.
//

import AppKit
import Combine
import Foundation

final class WindowManager {
    static let shared = WindowManager()

    private let drawerController = ClipMainWindowController.shared
    private let floatingController = ClipFloatingWindowController.shared

    private var cancellables = Set<AnyCancellable>()

    private init() {
        UserDefaults.standard.publisher(for: \.displayMode)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newRaw in
                self?.handleDisplayModeChange(to: newRaw)
            }
            .store(in: &cancellables)
    }

    // MARK: - 当前显示模式

    var displayMode: DisplayMode {
        let rawValue = UserDefaults.standard.integer(forKey: PrefKey.displayMode.rawValue)
        return DisplayMode(rawValue: rawValue) ?? .drawer
    }

    func toggleWindow(
        frame: NSRect? = nil,
        _ completionHandler: (@MainActor @Sendable () -> Void)? = nil
    ) {
        switch displayMode {
        case .drawer:
            dismissFloatingIfNeeded()
            drawerController.toggleWindow(frame, completionHandler)
        case .floating:
            dismissDrawerIfNeeded()
            floatingController.toggleWindow(completionHandler)
        }
    }

    var isVisible: Bool {
        drawerController.isVisible || floatingController.isVisible
    }

    var window: NSWindow? {
        switch displayMode {
        case .drawer: drawerController.window
        case .floating: floatingController.window
        }
    }

    func configureWindowSharing() {
        switch displayMode {
        case .drawer: drawerController.configureWindowSharing()
        case .floating: floatingController.configureWindowSharing()
        }
    }

    private func handleDisplayModeChange(to newRaw: Int) {
        switch DisplayMode(rawValue: newRaw) {
        case .drawer:
            drawerController.resetState()
        case .floating:
            floatingController.resetState()
        case nil:
            break
        }
    }

    private func dismissFloatingIfNeeded() {
        if floatingController.isVisible {
            floatingController.dismiss()
        }
    }

    private func dismissDrawerIfNeeded() {
        if drawerController.isVisible {
            drawerController.dismiss()
        }
    }
}
