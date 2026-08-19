//
//  WelcomeViewModel.swift
//  Clipboard
//

import AppKit
import ApplicationServices
import Observation

@MainActor
@Observable
final class WelcomeViewModel {
    private(set) var currentPage: WelcomePage = .introduction
    private(set) var isMovingForward = true
    private(set) var hasAccessibilityPermission = AXIsProcessTrusted()

    init(currentPage: WelcomePage = .introduction) {
        self.currentPage = currentPage
    }

    func select(_ page: WelcomePage) {
        isMovingForward = page.rawValue >= currentPage.rawValue
        currentPage = page
    }

    func goToNextPage() {
        guard let nextPage = currentPage.next else { return }
        select(nextPage)
    }

    func goToPreviousPage() {
        guard let previousPage = currentPage.previous else { return }
        select(previousPage)
    }

    func refreshAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
