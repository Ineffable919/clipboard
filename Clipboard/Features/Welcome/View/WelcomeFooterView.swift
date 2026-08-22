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
                WelcomeFooterActionsView(
                    viewModel: viewModel,
                    focusNamespace: focusNamespace
                )

                Spacer()

                if viewModel.currentPage == .permission {
                    WelcomePreferencesControlsView()
                        .frame(width: 286, alignment: .trailing)
                } else {
                    Color.clear
                        .frame(width: 286, height: 1)
                }
            }

            WelcomePageIndicatorView(viewModel: viewModel)
        }
        .padding(.horizontal, WelcomeStyle.horizontalPadding)
    }
}
