//
//  WelcomePageContentView.swift
//  Clipboard
//

import SwiftUI

#Preview {
    WelcomePageContentView(viewModel: WelcomeViewModel())
        .frame(width: WelcomeStyle.windowWidth, height: WelcomeStyle.windowHeight - WelcomeStyle.footerHeight)
}

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
