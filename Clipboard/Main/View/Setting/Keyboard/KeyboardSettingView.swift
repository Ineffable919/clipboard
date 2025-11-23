//
//  KeyboardSettingView.swift
//  Clipboard
//
//  Created by crown on 2025/10/28.
//

import KeyboardShortcuts
import SwiftUI

// MARK: - 键盘设置视图

struct KeyboardSettingView: View {
    @Environment(\.colorScheme) var colorScheme
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Clipboard"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                VStack(spacing: 0) {
                    KeyboardView(desc: "启动 \(appName)", key: .toggleClipKey)
                    Divider()
                        .padding(.vertical, Const.space8)
                    PasteView()
                }
                .padding(.vertical, Const.space8)
                .padding(.horizontal, Const.space16)
                .background(
                    RoundedRectangle(cornerRadius: Const.radius)
                        .fill(
                            colorScheme == .light
                                ? Const.lightBackground
                                : Const.darkBackground,
                        ),
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Const.radius)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1),
                )

                VStack(spacing: 0) {
                    QuickPasteModifierView()
                    Divider()
                        .padding(.vertical, Const.space8)
                    PlainTextModifierView()
                }
                .padding(.vertical, Const.space8)
                .padding(.horizontal, Const.space16)
                .background(
                    RoundedRectangle(cornerRadius: Const.radius)
                        .fill(
                            colorScheme == .light
                                ? Const.lightBackground
                                : Const.darkBackground,
                        ),
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Const.radius)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1),
                )
            }
        }
        .padding(24)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading,
        )
    }
}

struct KeyboardView: View {
    var desc: String
    var key: KeyboardShortcuts.Name

    var body: some View {
        HStack {
            Text(desc)
                .font(.body)
            Spacer()
            KeyboardShortcuts.Recorder(
                "",
                name: key,
            )
            .environment(\.locale, .init(identifier: "zh"))
        }
    }
}

struct PasteView: View {
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Clipboard"
    }

    var body: some View {
        HStack {
            Text("启动 \(appName)")
                .font(.body)
            Spacer()
            ShortcutRecorder(
                "paste_default",
                defaultValue: KeyboardShortcut(
                    modifiersRawValue: NSEvent.ModifierFlags([
                        .command, .shift,
                    ])
                    .rawValue,
                    keyCode: 0x08,
                    displayKey: "C",
                ),
            )
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
                .font(.body)
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
                    .font(.body)
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
