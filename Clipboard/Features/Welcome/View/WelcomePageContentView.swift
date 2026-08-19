//
//  WelcomePageContentView.swift
//  Clipboard
//

import SwiftUI

struct WelcomePageContentView: View {
    let viewModel: WelcomeViewModel

    var body: some View {
        switch viewModel.currentPage {
        case .introduction:
            WelcomeIntroductionPageView()
        case .shortcut:
            WelcomeShortcutPageView()
        case .permission:
            WelcomePermissionPageView(viewModel: viewModel)
        }
    }
}
