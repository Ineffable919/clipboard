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
