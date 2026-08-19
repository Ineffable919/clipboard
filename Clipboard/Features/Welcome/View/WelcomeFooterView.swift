//
//  WelcomeFooterView.swift
//  Clipboard
//

import SwiftUI

struct WelcomeFooterView: View {
    let viewModel: WelcomeViewModel
    let focusNamespace: Namespace.ID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.resetFocus) private var resetFocus
    @FocusState private var isPrimaryActionFocused: Bool

    var body: some View {
        HStack {
            Button(.previous) {
                navigate {
                    viewModel.goToPreviousPage()
                }
            }
            .buttonStyle(WelcomeSecondaryButtonStyle())
            .frame(width: 96, alignment: .leading)
            .opacity(viewModel.currentPage == .introduction ? 0 : 1)
            .disabled(viewModel.currentPage == .introduction)

            Spacer()

            HStack(spacing: 10) {
                ForEach(WelcomePage.allCases) { page in
                    Button {
                        navigate {
                            viewModel.select(page)
                        }
                    } label: {
                        Capsule()
                            .fill(
                                page == viewModel.currentPage
                                    ? WelcomeStyle.accent
                                    : WelcomeStyle.border
                            )
                            .frame(width: 40, height: 2)
                            .frame(width: 44, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .accessibilityLabel(Text(page.accessibilityLabel))
                }
            }

            Spacer()

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
            .frame(width: 84)
            .focusable()
            .overlay {
                RoundedRectangle(
                    cornerRadius: Const.btnRadius,
                    style: .continuous
                )
                .stroke(WelcomeStyle.accent.opacity(0.55), lineWidth: 2)
                .opacity(isPrimaryActionFocused ? 1 : 0)
                .allowsHitTesting(false)
            }
            .focused($isPrimaryActionFocused)
            .prefersDefaultFocus(in: focusNamespace)
            .frame(width: 96, alignment: .trailing)
        }
        .padding(.horizontal, WelcomeStyle.horizontalPadding)
        .padding(.bottom, 24)
        .task(id: viewModel.currentPage) {
            await Task.yield()
            isPrimaryActionFocused = true
        }
        .onChange(of: viewModel.currentPage) {
            resetFocus(in: focusNamespace)
        }
    }

    private func navigate(_ action: () -> Void) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
            action()
        }
    }
}
