//
//  SettingView.swift
//  Clipboard
//
//  Created on 2025/10/26.
//

import SwiftUI

enum SettingPage: CaseIterable, Identifiable {
    case general
    case appearance
    case privacy
    case keyboard
    case storage
    case ai
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
        case .ai:
            if #available(macOS 15.0, *) {
                "apple.intelligence"
            } else {
                "lasso.badge.sparkles"
            }
        case .about: "info.circle"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .general: .settingPageGeneral
        case .appearance: .settingPageAppearance
        case .privacy: .settingPagePrivacy
        case .keyboard: .settingPageKeyboard
        case .storage: .settingPageStorage
        case .ai: .settingPageMcp
        case .about: .settingPageAbout
        }
    }
}

struct SettingView: View {
    @Environment(SettingViewModel.self) private var viewModel
    @FocusState private var isSidebarFocused: Bool
    @AppStorage(PrefKey.pasteDirect.rawValue) private var pasteDirect = true

    var body: some View {
        @Bindable var vm = viewModel

        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $vm.selectedPage) {
                    ForEach(SettingPage.allCases) { page in
                        NavigationLink(value: page) {
                            HStack(spacing: Const.space8) {
                                Label {
                                    Text(page.title)
                                } icon: {
                                    Image(systemName: page.icon)
                                }

                                Spacer(minLength: Const.space8)

                                if !viewModel.hasAccessibilityPermission,
                                   page == .privacy || (page == .general && pasteDirect) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(nsColor: .systemRed))
                                        Image(systemName: "exclamationmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    .frame(width: 18, height: 18)
                                    .compositingGroup()
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel(
                                        Text(.settingPrivacyAccessibilityPermissionDenied)
                                    )
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .focused($isSidebarFocused)

                Spacer()

                HelpCenterButton()
                    .padding(.bottom, Const.space12)
                    .padding(.horizontal, Const.space8)
            }
            .frame(minWidth: 200)
        } detail: {
            Group {
                switch vm.selectedPage {
                case .general:
                    GeneralSettingView()
                case .appearance:
                    AppearanceSettingsView()
                case .privacy:
                    PrivacySettingView()
                case .keyboard:
                    KeyboardSettingView()
                case .storage:
                    StorageSettingView()
                case .ai:
                    AISettingsView()
                case .about:
                    AboutSettingView()
                }
            }
            .navigationTitle(Text(vm.selectedPage.title))
            .toolbarTitleDisplayMode(.inline)
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
        Button(action: {
            NSWorkspace.shared.open(Self.helpURL)
        }) {
            HStack {
                Image(systemName: "questionmark.circle")
                Text(.settingHelpCenter)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Const.space8)
            .padding(.vertical, Const.space6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let viewModel = SettingViewModel()
    SettingView()
        .frame(width: Const.settingWidth, height: Const.settingHeight)
        .environment(viewModel)
}
