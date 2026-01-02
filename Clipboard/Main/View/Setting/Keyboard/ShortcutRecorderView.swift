//
//  ShortcutRecorderView.swift
//  Clipboard
//
//  Created by crown on 2025/11/23.
//

import SwiftUI

// MARK: - 通用快捷键录入组件

struct ShortcutRecorder: View {
    private let hotKeyId: String
    private let onShortcutChanged: (() -> Void)?

    @State private var shortcut: KeyboardShortcut
    @State private var displayText: String
    @State private var isRecording: Bool = false
    @State private var viewFrame: CGRect = .zero
    @State private var mouseMonitor: Any?

    @Binding var value: KeyboardShortcut

    init(
        _ key: String,
        binding: Binding<KeyboardShortcut>? = nil,
        onShortcutChanged: (() -> Void)? = nil
    ) {
        hotKeyId = key
        self.onShortcutChanged = onShortcutChanged

        let saved =
            HotKeyManager.shared.getHotKey(key: key)?.shortcut ?? .empty

        _shortcut = State(initialValue: saved)
        _displayText = State(initialValue: saved.displayString)
        _value =
            binding
                ?? Binding(
                    get: { saved },
                    set: { _ in }
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
        .frame(maxWidth: 128.0, minHeight: Const.space24)
        .background(
            RoundedRectangle(cornerRadius: Const.radius)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: Const.radius)
                        .strokeBorder(borderColor, lineWidth: borderSize)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            startRecording()
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        viewFrame = geo.frame(in: .global)
                    }
                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                        viewFrame = newFrame
                    }
            }
        )
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
        installEventHandle()
    }

    private func stopRecording() {
        isRecording = false
        if shortcut.isEmpty {
            displayText = "请录入快捷键…"
        } else {
            displayText = shortcut.displayString
        }
        uninstallEventHandle()
    }

    // MARK: - 注册EventHandle

    private func installEventHandle() {
        EventDispatcher.shared.registerHandler(
            matching: .keyDown,
            key: "shortcutRecorder",
        ) { [self] event in
            return handleKeyEvent(event)
        }

        mouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .leftMouseDown
        ) { [self] event in
            return handleMouseEvent(event)
        }
    }

    private func uninstallEventHandle() {
        EventDispatcher.shared.unregisterHandler("shortcutRecorder")

        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }

    private func handleMouseEvent(_ event: NSEvent) -> NSEvent? {
        guard isRecording else { return event }
        guard let window = event.window,
              window === SettingWindowController.shared.window
        else {
            return event
        }

        let windowLocation = event.locationInWindow
        let flippedY = window.frame.height - windowLocation.y
        let flippedLocation = CGPoint(x: windowLocation.x, y: flippedY)

        if !viewFrame.contains(flippedLocation) {
            stopRecording()
        }

        return event
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window === SettingWindowController.shared.window else {
            return event
        }
        guard isRecording else { return event }

        let keyCode = event.keyCode

        if keyCode == KeyCode.escape {
            stopRecording()
            return nil
        }

        let modifiers = event.modifierFlags.intersection([
            .command, .option, .control, .shift,
        ])

        let isFunctionKey =
            (0x7A ... 0x7D).contains(keyCode)
                || [0x63, 0x76, 0x60, 0x61, 0x62, 0x64, 0x65, 0x6D, 0x67, 0x6F]
                .contains(keyCode)

        if modifiers.isEmpty, !isFunctionKey {
            return event
        }

        guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty
        else {
            return event
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
        return nil
    }

    private func save() {
        if shortcut.isEmpty {
            HotKeyManager.shared.deleteHotKey(key: hotKeyId)
        } else {
            if HotKeyManager.shared.getHotKey(key: hotKeyId) != nil {
                HotKeyManager.shared.updateHotKey(
                    key: hotKeyId,
                    shortcut: shortcut,
                    isEnabled: true,
                )
            } else {
                HotKeyManager.shared.addHotKey(
                    key: hotKeyId,
                    shortcut: shortcut,
                )
            }
            onShortcutChanged?()
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
                "app_launch",
            )
        }
    }
    .padding(30)
    .frame(width: 400)
}
