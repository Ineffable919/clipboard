//
//  SettingView.swift
//  Clipboard
//
//  Created on 2025/10/26.
//

import SwiftUI

/// 设置页面导航选项
enum SettingPage: String, CaseIterable, Identifiable {
    case general = "通用"
    case appearance = "外观"
    case privacy = "隐私"
    case keyboard = "快捷键"
    case about = "关于"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "gear"
        case .appearance: "paintpalette"
        case .privacy: "hand.raised"
        case .keyboard: "command"
        case .about: "info.circle"
        }
    }
}

struct SettingView: View {
    @State private var selectedPage: SettingPage = .general
    @FocusState private var isSidebarFocused: Bool

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selectedPage) {
                    ForEach(SettingPage.allCases) { page in
                        NavigationLink(value: page) {
                            Label(page.rawValue, systemImage: page.icon)
                        }
                    }
                }
                .listStyle(.sidebar)
                .focused($isSidebarFocused)

                Spacer()

                HelpCenterButton()
                    .padding(.bottom, Const.space12)
                    .padding(.horizontal, 8)
            }
            .padding(.vertical, 8)
            .frame(minWidth: 150)
        } detail: {
            NavigationStack {
                Group {
                    switch selectedPage {
                    case .general:
                        GeneralSettingView()
                    case .appearance:
                        AppearanceSettingsView()
                    case .privacy:
                        PrivacySettingView()
                    case .keyboard:
                        KeyboardSettingView()
                    case .about:
                        AboutSettingView()
                    }
                }
                .navigationTitle(selectedPage.rawValue)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            isSidebarFocused = true
        }
    }
}

// MARK: - 设置开关行

struct SettingToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 帮助中心按钮

struct HelpCenterButton: View {
    var body: some View {
        Button(action: {
            if let url = URL(
                string:
                "https://github.com/Ineffable919/clipboard/blob/master/README.md",
            ) {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack {
                Image(systemName: "questionmark.circle")
                Text("帮助中心")
                    .font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Const.space8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

#Preview {
    SettingView()
        .frame(width: Const.settingWidth, height: Const.settingHeight)
}
