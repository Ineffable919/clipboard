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
            topDragArea

            HStack(spacing: Const.space12) {
                searchField
                settingsButton
            }
            .padding(.top, Const.space6)
            .padding(.horizontal, FloatConst.horizontalPadding)

            Spacer()
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .windowDraggable()

            chipScrollView
                .padding(.bottom, Const.space10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: FloatConst.headerHeight)
        .onAppear {
            EventDispatcher.shared.registerHandler(
                matching: .keyDown,
                key: "floatingTop",
                handler: floatingKeyDownEvent(_:)
            )
            topBarVM.startPauseDisplayTimer()
        }
    }

    // MARK: - 顶部拖拽区域

    private var topDragArea: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: Const.space6)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36.0, height: 4.0)

            Spacer()
                .frame(height: Const.space4)
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .windowDraggable()
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
            RoundedRectangle(cornerRadius: Const.radius)
                .fill(searchFieldBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Const.radius + 3)
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
                            topBarVM.toggleChip(chip)
                            guard env.focusView != .history else { return }
                            focus = nil
                            env.focusView = .history
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
            .buttonStyle(.plain)
    }

    // MARK: - 键盘事件处理

    private func floatingKeyDownEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window === ClipFloatingWindowController.shared.window
        else {
            return event
        }

        let isInInputMode = env.focusView == .search

        if isInInputMode {
            if EventDispatcher.shared.handleSystemEditingCommand(event) {
                return nil
            }

            if event.keyCode == KeyCode.escape {
                if topBarVM.hasInput {
                    topBarVM.clearInput()
                } else {
                    focus = nil
                    env.focusView = .history
                }
                return nil
            }

            return event
        }

        if KeyCode.shouldTriggerSearch(for: event) {
            env.focusView = .search
            focus = .search
            return nil
        }

        return event
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
                RoundedRectangle(cornerRadius: Const.radius)
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
