//
//  KeyboardSettingView.swift
//  Clipboard
//
//  Created by crown on 2025/10/28.
//

import SwiftUI

// MARK: - 键盘设置视图

struct KeyboardSettingView: View {
    @State private var resetIsPresented = false
    @State private var refreshID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                VStack(spacing: 0) {
                    StartupShortcutsView()
                }
                .settingsStyle()
                .id(refreshID)

                VStack(spacing: 0) {
                    PreviousTabView()
                    Divider()
                    NextTabView()
                }
                .settingsStyle()
                .id(refreshID)

                VStack(spacing: 0) {
                    QuickPasteModifierView(refreshID: $refreshID)
                    Divider()
                        .padding(.vertical, Const.space8)
                    PlainTextModifierView(refreshID: $refreshID)
                }
                .padding(.vertical, Const.space8)
                .padding(.leading, Const.space16)
                .padding(.trailing, Const.space10)
                .settingsStyle()

                HStack {
                    Spacer()
                    BorderedButton(title: "重置快键方式为默认...") {
                        resetIsPresented = true
                    }
                    .confirmationDialog("您确定将所有的快键方式重置为默认值吗？", isPresented: $resetIsPresented) {
                        if #available(macOS 26.0, *) {
                            Button("重置", role: .confirm) {
                                HotKeyManager.shared.resetToDefaults()
                                refreshID = UUID()
                            }
                        } else {
                            Button("重置") {
                                HotKeyManager.shared.resetToDefaults()
                                refreshID = UUID()
                            }
                        }
                        Button("取消", role: .cancel) {
                            resetIsPresented = false
                        }
                    }
                }
            }
        }
        .padding(Const.space24)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
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
                WindowManager.shared.toggleWindow()
            }
        }
        .padding(.vertical, Const.space4)
        .padding(.leading, Const.space16)
        .padding(.trailing, Const.space8)
    }
}

struct PreviousTabView: View {
    var body: some View {
        HStack {
            Text("显示上一个 Tab")
            Spacer()
            ShortcutRecorder("previous_tab")
        }
        .padding(.vertical, Const.space4)
        .padding(.leading, Const.space16)
        .padding(.trailing, Const.space8)
    }
}

struct NextTabView: View {
    var body: some View {
        HStack {
            Text("显示下一个 Tab")
            Spacer()
            ShortcutRecorder("next_tab")
        }
        .padding(.vertical, Const.space4)
        .padding(.leading, Const.space16)
        .padding(.trailing, Const.space8)
    }
}

// MARK: - 快速粘贴修饰键视图

struct QuickPasteModifierView: View {
    @State private var selectedModifier: Int = PasteUserDefaults.quickPasteModifier
    @Binding var refreshID: UUID

    private let modifiers = [
        (id: 0, symbol: "⌘", name: "Command"),
        (id: 1, symbol: "⌥", name: "Option"),
        (id: 2, symbol: "⌃", name: "Control"),
    ]

    var body: some View {
        HStack {
            Text("快速粘贴")
            Spacer()
            HStack(spacing: Const.space4) {
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
                .onChange(of: refreshID) {
                    selectedModifier = PasteUserDefaults.quickPasteModifier
                }

                Text("+ 1...9")
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - 纯文本粘贴修饰键视图

struct PlainTextModifierView: View {
    @State private var selectedModifier: Int = PasteUserDefaults.plainTextModifier
    @Binding var refreshID: UUID

    private let modifiers = [
        (id: 0, symbol: "⌘", name: "Command"),
        (id: 1, symbol: "⌥", name: "Option"),
        (id: 2, symbol: "⌃", name: "Control"),
        (id: 3, symbol: "⇧", name: "Shift"),
    ]

    var body: some View {
        HStack {
            Text("粘贴为纯文本")
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
            .onChange(of: refreshID) {
                selectedModifier = PasteUserDefaults.plainTextModifier
            }
        }
    }
}

#Preview {
    KeyboardSettingView()
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
