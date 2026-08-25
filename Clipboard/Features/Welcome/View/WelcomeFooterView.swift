//
//  WelcomeFooterView.swift
//  Clipboard
//

import SwiftUI

struct WelcomeFooterView: View {
    let viewModel: WelcomeViewModel
    let focusNamespace: Namespace.ID

    var body: some View {
        ZStack {
            HStack {
                if viewModel.currentPage == .permission {
                    WelcomePreferencesControlsView()
                        .frame(width: 286, alignment: .leading)
                } else {
                    Color.clear
                        .frame(width: 286, height: 1)
                }

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
