//
//  WelcomeView.swift
//  Clipboard
//

import SwiftUI

struct WelcomeView: View {
    @State private var viewModel: WelcomeViewModel
    @Namespace private var focusNamespace
    @Environment(\.colorScheme) private var colorScheme

    init(initialPage: WelcomePage = .introduction) {
        _viewModel = State(
            initialValue: WelcomeViewModel(currentPage: initialPage)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            WelcomeHeaderView(
                showsSkip: viewModel.currentPage != .permission
            )

            ZStack {
                WelcomePageContentView(viewModel: viewModel)
                    .id(viewModel.currentPage)
                    .transition(
                        .asymmetric(
                            insertion: .move(
                                edge: viewModel.isMovingForward
                                    ? .trailing
                                    : .leading
                            ).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            WelcomeFooterView(
                viewModel: viewModel,
                focusNamespace: focusNamespace
            )
        }
        .focusScope(focusNamespace)
        .background(WelcomeStyle.background(for: colorScheme))
        .foregroundStyle(WelcomeStyle.primaryText(for: colorScheme))
        .tint(WelcomeStyle.accent)
    }
}

#Preview("Introduction") {
    WelcomeView(initialPage: .introduction)
        .frame(
            width: WelcomeStyle.windowWidth,
            height: WelcomeStyle.windowHeight
        )
}

#Preview("Shortcut") {
    WelcomeView(initialPage: .shortcut)
        .frame(
            width: WelcomeStyle.windowWidth,
            height: WelcomeStyle.windowHeight
        )
}

#Preview("Permission") {
    WelcomeView(initialPage: .permission)
        .frame(
            width: WelcomeStyle.windowWidth,
            height: WelcomeStyle.windowHeight
        )
}
