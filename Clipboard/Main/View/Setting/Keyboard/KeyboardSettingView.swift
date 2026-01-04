//
//  KeyboardSettingView.swift
//  Clipboard
//
//  Created by crown on 2025/10/28.
//

import SwiftUI

// MARK: - 键盘设置视图

struct KeyboardSettingView: View {
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                VStack(spacing: 0) {
                    StartupShortcutsView()
                }
                .padding(.vertical, Const.space4)
                .padding(.horizontal, Const.space16)
                .settingsStyle()

                VStack(spacing: 0) {
                    PreviousTabView()
                    Divider()
                        .padding(.vertical, Const.space4)
                    NextTabView()
                }
                .padding(.vertical, Const.space4)
                .padding(.horizontal, Const.space16)
                .settingsStyle()

                VStack(spacing: 0) {
                    QuickPasteModifierView()
                    Divider()
                        .padding(.vertical, Const.space8)
                    PlainTextModifierView()
                }
                .padding(.vertical, Const.space8)
                .padding(.horizontal, Const.space16)
                .settingsStyle()
            }
        }
        .padding(Const.space24)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading,
        )
    }
}

struct StartupShortcutsView: View {
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Clipboard"
    }

    var body: some View {
        HStack {
            Text("启动 \(appName)")
            Spacer()
            ShortcutRecorder("app_launch") {
                ClipMainWindowController.shared.toggleWindow()
            }
        }
    }
}

struct PreviousTabView: View {
    var body: some View {
        HStack {
            Text("显示上一个 Tab")
            Spacer()
            ShortcutRecorder("previous_tab")
        }
    }
}

struct NextTabView: View {
    var body: some View {
        HStack {
            Text("显示下一个 Tab")
            Spacer()
            ShortcutRecorder("next_tab")
        }
    }
}

// MARK: - 快速粘贴修饰键视图

struct QuickPasteModifierView: View {
    @State private var selectedModifier: Int = PasteUserDefaults
        .quickPasteModifier

    private let modifiers = [
        (id: 0, symbol: "⌘", name: "Command"),
        (id: 1, symbol: "⌥", name: "Option"),
        (id: 2, symbol: "⌃", name: "Control"),
    ]

    var body: some View {
        HStack {
            Text("快速粘贴")
            Spacer()
            HStack(spacing: 4) {
                Picker("", selection: $selectedModifier) {
                    ForEach(modifiers, id: \.id) { modifier in
                        Text("\(modifier.symbol) \(modifier.name)")
                            .tag(modifier.id)
                    }
                }
                .pickerStyle(.menu)
                .buttonStyle(.borderless)
                .onChange(of: selectedModifier) {
                    PasteUserDefaults.quickPasteModifier = selectedModifier
                }

                Text("+ 1...9")
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - 纯文本粘贴修饰键视图

struct PlainTextModifierView: View {
    @State private var selectedModifier: Int = PasteUserDefaults
        .plainTextModifier

    private let modifiers = [
        (id: 0, symbol: "⌘", name: "Command"),
        (id: 1, symbol: "⌥", name: "Option"),
        (id: 2, symbol: "⌃", name: "Control"),
        (id: 3, symbol: "⇧", name: "Shift"),
    ]

    var body: some View {
        HStack {
            Text("粘贴为纯文本")
                .font(.body)
            Spacer()
            Picker("", selection: $selectedModifier) {
                ForEach(modifiers, id: \.id) { modifier in
                    Text("\(modifier.symbol) \(modifier.name)")
                        .tag(modifier.id)
                }
            }
            .pickerStyle(.menu)
            .buttonStyle(.borderless)
            .onChange(of: selectedModifier) {
                PasteUserDefaults.plainTextModifier = selectedModifier
            }
        }
    }
}

#Preview {
    KeyboardSettingView()
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
