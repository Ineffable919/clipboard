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
                    SystemButton(title: String(localized: .settingKeyboardResetShortcuts)) {
                        resetIsPresented = true
                    }
                    .confirmationDialog(
                        String(localized: .settingKeyboardResetConfirmationMessage),
                        isPresented: $resetIsPresented
                    ) {
                        if #available(macOS 26.0, *) {
                            Button(.settingKeyboardResetButton, role: .confirm) {
                                HotKeyManager.shared.resetToDefaults()
                                refreshID = UUID()
                            }
                        } else {
                            Button(.settingKeyboardResetButton) {
                                HotKeyManager.shared.resetToDefaults()
                                refreshID = UUID()
                            }
                        }
                        Button(.commonCancel, role: .cancel) {
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
            Text(
                String.localizedStringWithFormat(
                    String(
                        localized: "settingKeyboardLaunchApp",
                        defaultValue: "Launch %@",
                        table: "Localizable"
                    ),
                    appName
                )
            )
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
            Text(.settingKeyboardPreviousTab)
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
            Text(.settingKeyboardNextTab)
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
            Text(.settingKeyboardQuickPaste)
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
                .onChange(of: selectedModifier) { _, _ in
                    PasteUserDefaults.quickPasteModifier = selectedModifier
                }
                .onChange(of: refreshID) { _, _ in
                    selectedModifier = PasteUserDefaults.quickPasteModifier
                }

                Text(.settingKeyboardQuickPasteSuffix)
                    .foregroundStyle(.primary)
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
            Text(.settingKeyboardPasteAsPlainText)
            Spacer()
            Picker("", selection: $selectedModifier) {
                ForEach(modifiers, id: \.id) { modifier in
                    Text("\(modifier.symbol) \(modifier.name)")
                        .tag(modifier.id)
                }
            }
            .pickerStyle(.menu)
            .buttonStyle(.borderless)
            .onChange(of: selectedModifier) { _, _ in
                PasteUserDefaults.plainTextModifier = selectedModifier
            }
            .onChange(of: refreshID) { _, _ in
                selectedModifier = PasteUserDefaults.plainTextModifier
            }
        }
    }
}

#Preview {
    KeyboardSettingView()
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
