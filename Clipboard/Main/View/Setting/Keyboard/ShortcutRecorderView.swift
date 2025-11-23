//
//  ShortcutRecorderView.swift
//  Clipboard
//
//  Created by crown on 2025/11/23.
//

import SwiftUI

// MARK: - 快捷键模型

struct KeyboardShortcut: Codable, Equatable, Hashable {
    var modifiersRawValue: UInt = 0
    var keyCode: UInt16 = 0
    var displayKey: String = ""

    var modifiers: NSEvent.ModifierFlags {
        get { NSEvent.ModifierFlags(rawValue: modifiersRawValue) }
        set { modifiersRawValue = newValue.rawValue }
    }

    var isEmpty: Bool { displayKey.isEmpty && modifiersRawValue == 0 }

    var displayString: String {
        guard !isEmpty else { return "" }
        return modifiers.symbols + displayKey
    }

    static var empty = KeyboardShortcut()
}

extension NSEvent.ModifierFlags {
    var symbols: String {
        var s = ""
        if contains(.command) { s += "⌘" }
        if contains(.option) { s += "⌥" }
        if contains(.control) { s += "⌃" }
        if contains(.shift) { s += "⇧" }
        return s
    }
}

// MARK: - UserDefaults 扩展（支持 Codable）

extension UserDefaults {
    func set(encodable: (some Codable)?, forKey key: String) {
        if let data = try? JSONEncoder().encode(encodable) {
            set(data, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }

    func object<T: Codable>(_: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - 通用快捷键录入组件

struct ShortcutRecorder: View {
    private let storageKey: String
    private let defaultValue: KeyboardShortcut

    @State private var shortcut: KeyboardShortcut
    @State private var displayText: String
    @State private var isRecording: Bool = false
    @State private var eventMonitor: Any?

    @Binding var value: KeyboardShortcut

    init(
        _ key: String,
        defaultValue: KeyboardShortcut = .empty,
        binding: Binding<KeyboardShortcut>? = nil
    ) {
        storageKey = key
        self.defaultValue = defaultValue

        let saved =
            UserDefaults.standard.object(KeyboardShortcut.self, forKey: key)
            ?? defaultValue
        _shortcut = State(initialValue: saved)
        _displayText = State(initialValue: saved.displayString)
        _value =
            binding
            ?? Binding(
                get: { saved },
                set: { _ in },
            )
    }

    var body: some View {
        HStack {
            Text(displayText)
                .font(.system(size: 13))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .center)

            if !shortcut.isEmpty, !isRecording {
                Button {
                    shortcut = KeyboardShortcut.empty
                    displayText = "请录入快捷键…"
                    save()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4.0)
        .padding(.vertical, 6.0)
        .frame(maxWidth: 128.0, minHeight: Const.space24)
        .background(
            RoundedRectangle(cornerRadius: Const.space24)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: Const.space24)
                        .strokeBorder(borderColor, lineWidth: borderSize),
                ),
        )
        .contentShape(Rectangle())
        .onTapGesture {
            startRecording()
        }
        .onAppear {
            value = shortcut
            if shortcut.isEmpty {
                displayText = "请录入快捷键…"
            }
        }
        .onDisappear {
            stopRecording()
        }
        .onChange(of: shortcut) {
            value = shortcut
        }
        .onChange(of: isRecording) {
            if isRecording {
                installEventMonitor()
            } else {
                removeEventMonitor()
            }
        }
    }

    private var textColor: Color {
        shortcut.isEmpty ? .secondary : .primary
    }

    private var borderColor: Color {
        isRecording
            ? .accentColor.opacity(0.4)
            : Color(NSColor.tertiaryLabelColor).opacity(0.2)
    }

    private var borderSize: CGFloat {
        isRecording ? 3.0 : 1.0
    }

    // MARK: - 录入状态管理

    private func startRecording() {
        isRecording = true
        displayText = "按下快捷键"
    }

    private func stopRecording() {
        isRecording = false
        if shortcut.isEmpty {
            displayText = "请录入快捷键…"
        } else {
            displayText = shortcut.displayString
        }
    }

    // MARK: - 事件监听器管理

    private func installEventMonitor() {
        removeEventMonitor()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [self] event in
            guard isRecording else { return event }

            handleKeyEvent(event)

            // 关键：只有在成功录入时才拦截事件，避免影响其他监听器
            // 如果用户按了 Esc 或其他取消操作，让事件继续传播
            return nil
        }
    }

    private func removeEventMonitor() {
        if eventMonitor != nil {
            EventMonitorManager.shared.removeMonitor(type: .shortcutRecorder)
            eventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let keyCode = event.keyCode

        if keyCode == 0x35 {
            stopRecording()
            return
        }

        let modifiers = event.modifierFlags.intersection([
            .command, .option, .control, .shift,
        ])

        let isFunctionKey =
            (0x7A...0x7D).contains(keyCode)
            || [0x63, 0x76, 0x60, 0x61, 0x62, 0x64, 0x65, 0x6D, 0x67, 0x6F]
                .contains(keyCode)

        if modifiers.isEmpty, !isFunctionKey {
            return
        }

        guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty
        else {
            return
        }

        let specialMap: [UInt16: String] = [
            0x33: "⌫", 0x75: "⌦", 0x24: "↩", 0x4C: "⌅",
            0x31: "Space", 0x30: "⇥",
            0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5",
            0x61: "F6", 0x62: "F7", 0x64: "F8", 0x65: "F9", 0x6D: "F10",
            0x67: "F11", 0x6F: "F12",
        ]

        let displayKey = specialMap[keyCode] ?? chars.uppercased()
        shortcut = KeyboardShortcut(
            modifiersRawValue: modifiers.rawValue,
            keyCode: keyCode,
            displayKey: displayKey,
        )

        stopRecording()
        save()
    }

    private func save() {
        if shortcut.isEmpty {
            UserDefaults.standard.set(
                encodable: nil as KeyboardShortcut?,
                forKey: storageKey,
            )
        } else {
            UserDefaults.standard.set(encodable: shortcut, forKey: storageKey)
        }
    }
}

// MARK: - Preview

#Preview("快捷键录入") {
    VStack(spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
            Text("空状态")
                .font(.caption)
                .foregroundStyle(.secondary)
            ShortcutRecorder("preview_empty")
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("预设快捷键")
                .font(.caption)
                .foregroundStyle(.secondary)
            ShortcutRecorder(
                "preview_default",
                defaultValue: KeyboardShortcut(
                    modifiersRawValue: NSEvent.ModifierFlags([.command, .shift])
                        .rawValue,
                    keyCode: 0x08,
                    displayKey: "V",
                ),
            )
        }
    }
    .padding(30)
    .frame(width: 400)
}
