//
//  WelcomePageIndicatorView.swift
//  Clipboard
//

import SwiftUI

struct WelcomePageIndicatorView: View {
    let viewModel: WelcomeViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: Const.space8) {
            ForEach(WelcomePage.allCases) { page in
                Button {
                    withAnimation(
                        reduceMotion ? nil : .easeInOut(duration: 0.28)
                    ) {
                        viewModel.select(page)
                    }
                } label: {
                    Circle()
                        .fill(
                            page == viewModel.currentPage
                                ? WelcomeStyle.accent
                                : WelcomeStyle.tertiaryText(
                                    for: colorScheme
                                ).opacity(0.55)
                        )
                        .frame(width: 7, height: 7)
                        .frame(width: 18, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityLabel(Text(page.accessibilityLabel))
                .accessibilityAddTraits(
                    page == viewModel.currentPage ? .isSelected : []
                )
            }
        }
    }
}
