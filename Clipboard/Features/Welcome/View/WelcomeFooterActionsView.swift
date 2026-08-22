//
//  WelcomeFooterActionsView.swift
//  Clipboard
//

import SwiftUI

struct WelcomeFooterActionsView: View {
    let viewModel: WelcomeViewModel
    let focusNamespace: Namespace.ID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.resetFocus) private var resetFocus
    @FocusState private var isPrimaryActionFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            if viewModel.currentPage != .introduction {
                Button(.previous) {
                    navigate {
                        viewModel.goToPreviousPage()
                    }
                }
                .buttonStyle(WelcomeSecondaryButtonStyle())
                .frame(width: 72)
            }

            Button {
                if viewModel.currentPage == .permission {
                    WelcomeWindowController.shared.finishWelcome()
                } else {
                    navigate {
                        viewModel.goToNextPage()
                    }
                }
            } label: {
                Text(
                    viewModel.currentPage == .permission
                        ? .start
                        : .continue
                )
            }
            .buttonStyle(WelcomePrimaryButtonStyle())
            .frame(width: 72)
            .focusable()
            .focusEffectDisabled()
            .overlay {
                RoundedRectangle(
                    cornerRadius: Const.btnRadius,
                    style: .continuous
                )
                .stroke(WelcomeStyle.accent.opacity(0.45), lineWidth: 1)
                .opacity(isPrimaryActionFocused ? 1 : 0)
                .allowsHitTesting(false)
            }
            .focused($isPrimaryActionFocused)
            .prefersDefaultFocus(in: focusNamespace)

        }
        .task(id: viewModel.currentPage) {
            await Task.yield()
            isPrimaryActionFocused = true
        }
        .onChange(of: viewModel.currentPage) {
            resetFocus(in: focusNamespace)
        }
    }

    private func navigate(_ action: () -> Void) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
            action()
        }
    }
}
