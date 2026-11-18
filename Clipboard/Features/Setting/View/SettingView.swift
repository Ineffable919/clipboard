//
//  SettingView.swift
//  Clipboard
//
//  Created by crown on 2025/10/26
//

import SwiftUI

enum SettingPage: CaseIterable, Identifiable {
    case general
    case appearance
    case privacy
    case keyboard
    case storage
    case mcp
    case about

    var id: Self {
        self
    }

    var icon: String {
        switch self {
        case .general: "gear"
        case .appearance: "paintpalette"
        case .privacy: "hand.raised"
        case .keyboard: "command"
        case .storage: "externaldrive"
        case .mcp: "sparkles"
        case .about: "info.circle"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .general: .pageGeneral
        case .appearance: .pageAppearance
        case .privacy: .pagePrivacy
        case .keyboard: .pageKeyboard
        case .storage: .pageStorage
        case .mcp: .pageMcp
        case .about: .pageAbout
        }
    }
}

struct SettingSidebarView: View {
    @Environment(SettingViewModel.self) private var viewModel
    @FocusState private var isSidebarFocused: Bool
    @AppStorage(PrefKey.pasteDirect.rawValue) private var pasteDirect = true

    var body: some View {
        @Bindable var model = viewModel

        VStack(spacing: 0) {
            List(selection: $model.selectedPage) {
                ForEach(SettingPage.allCases) { page in
                    HStack(spacing: Const.space8) {
                        Label {
                            Text(page.title)
                        } icon: {
                            Image(systemName: page.icon)
                        }

                        Spacer(minLength: Const.space8)

                        if page == .general,
                            pasteDirect,
                            !viewModel.hasAccessibilityPermission
                        {
                            AccessibilityWarningBadge(diameter: Const.iconSize18)
                                .compositingGroup()
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(
                                    Text(.privacyAccessPermissionDenied)
                                )
                        }
                    }
                    .tag(page)
                }
            }
            .listStyle(.sidebar)
            .focused($isSidebarFocused)

            Spacer()

            HelpCenterButton()
                .padding(.bottom, Const.space12)
                .padding(.horizontal, Const.space8)
        }
        .onAppear {
            viewModel.refreshAccessibilityPermission()
            Task { @MainActor in
                isSidebarFocused = true
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            viewModel.refreshAccessibilityPermission()
        }
    }
}

// MARK: - 设置开关行

struct SettingToggleRow: View {
    let title: LocalizedStringResource
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.vertical, Const.space8)
    }
}

// MARK: - 帮助中心按钮

struct HelpCenterButton: View {
    private static let helpURL = URL(string: "https://github.com/Ineffable919/clipboard/blob/master/README.md")!

    var body: some View {
        Button(
            action: {
                NSWorkspace.shared.open(Self.helpURL)
            },
            label: {
                HStack {
                    Image(systemName: "questionmark.circle")
                    Text(.help)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Const.space8)
                .padding(.vertical, Const.space6)
            }
        )
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingWindowController.makeContentController(viewModel: SettingViewModel())
}
