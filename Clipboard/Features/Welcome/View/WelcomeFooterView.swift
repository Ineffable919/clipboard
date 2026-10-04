//
//  WelcomeFooterView.swift
//  Clipboard
//

import SwiftUI

#Preview {
    @Previewable @Namespace var focusNamespace

    WelcomeFooterView(viewModel: WelcomeViewModel(currentPage: .shortcut), focusNamespace: focusNamespace)
        .frame(width: WelcomeStyle.windowWidth, height: WelcomeStyle.footerHeight)
        .focusScope(focusNamespace)
}

struct WelcomeFooterView: View {
    let viewModel: WelcomeViewModel
    let focusNamespace: Namespace.ID

    var body: some View {
        ZStack {
            HStack {
                Spacer()

                WelcomeFooterActionsView(
                    viewModel: viewModel,
                    focusNamespace: focusNamespace
                )
            }

            WelcomePageIndicatorView(viewModel: viewModel)
        }
        .padding(.horizontal, WelcomeStyle.horizontalPadding)
    }
}
