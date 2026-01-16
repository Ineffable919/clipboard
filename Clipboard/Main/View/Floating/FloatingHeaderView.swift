//
//  FloatingHeaderView.swift
//  Clipboard
//
//  Created by crown on 2026/1/14.
//

import SwiftUI

struct FloatingHeaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppEnvironment.self) private var env
    @AppStorage(PrefKey.backgroundType.rawValue) private var backgroundTypeRaw:
        Int = 0
    @FocusState private var focus: FocusField?
    @State private var topBarVM = TopBarViewModel()
    @State private var showFilter = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Const.space12) {
                searchField
                settingsButton
            }
            .padding(.top, Const.space16)
            .padding(.horizontal, FloatConst.horizontalPadding)

            Spacer()

            chipScrollView
                .padding(.bottom, Const.space10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: FloatConst.headerHeight)
        .onChange(of: env.focusView) {
            syncFocusFromEnv()
        }
        .onAppear {
            topBarVM.startPauseDisplayTimer()
        }
    }

    // MARK: - 搜索框

    private var searchField: some View {
        HStack(spacing: Const.space6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14.0, weight: .regular))
                .foregroundStyle(.secondary)

            TextField("搜索...", text: $topBarVM.query)
                .textFieldStyle(.plain)
                .focused($focus, equals: .search)
                .onChange(of: focus) {
                    if focus == .search, env.focusView != .search {
                        env.focusView = .search
                    }
                }
        }
        .padding(.horizontal, Const.space10)
        .padding(.vertical, Const.space6)
        .background {
            Capsule()
                .fill(searchFieldBackground)
        }
        .overlay {
            Capsule()
                .strokeBorder(
                    focus == .search
                        ? Color.accentColor.opacity(0.45)
                        : Color.clear,
                    lineWidth: 3
                )
                .padding(-3)
        }
    }

    private var searchFieldBackground: some ShapeStyle {
        if colorScheme == .dark {
            AnyShapeStyle(Color.white.opacity(0.1))
        } else {
            AnyShapeStyle(Color.black.opacity(0.05))
        }
    }

    // MARK: - 设置按钮

    private var settingsButton: some View {
        Button("设置", systemImage: "gearshape") {
            SettingWindowController.shared.toggleWindow()
        }
        .labelStyle(.iconOnly)
        .font(.system(size: 16, weight: .regular))
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
    }

    // MARK: - 分类标签

    private var chipScrollView: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Const.space8) {
                ForEach(topBarVM.chips) { chip in
                    FloatingChipView(
                        chip: chip,
                        isSelected: topBarVM.selectedChipId == chip.id,
                        onTap: {
                            topBarVM.clearInput()
                            topBarVM.toggleChip(chip)
                            if env.focusView != .history {
                                focus = nil
                                env.focusView = .history
                            }
                        }
                    )
                }

                addChipButton
            }
            .padding(.horizontal, FloatConst.horizontalPadding)
        }
        .scrollIndicators(.hidden)
        .onTapGesture {
            guard env.focusView != .history else { return }
            focus = nil
            env.focusView = .history
        }
    }

    private var addChipButton: some View {
        Button("", systemImage: "plus") {}
            .labelStyle(.iconOnly)
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 24)
            .background {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
            }
            .buttonStyle(.plain)
    }

    private func syncFocusFromEnv() {
        if env.focusView.requiresSystemFocus {
            Task { @MainActor in
                focus = env.focusView
            }
        }
    }
}

// MARK: - 分类标签视图

struct FloatingChipView: View {
    let chip: CategoryChip
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Const.space4) {
                Text(chip.name)
                    .foregroundStyle(
                        isSelected ? .white : .primary.opacity(0.8)
                    )
            }
            .padding(.horizontal, Const.space10)
            .padding(.vertical, Const.space4)
            .background {
                Capsule()
                    .fill(
                        isSelected
                            ? chip.isSystem ? .accentColor : chip.color
                            : .clear
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let env = AppEnvironment()
    FloatingHeaderView()
        .environment(env)
        .frame(width: 370, height: 90)
}
