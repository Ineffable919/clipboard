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
    @Environment(\.colorScheme) var colorScheme

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
        ZStack(alignment: .trailing) {
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
                    Image(systemName: "xmark")
                        .resizable()
                        .foregroundStyle(.primary)
                        .frame(width: Const.space8, height: Const.space8)
                        .padding(.trailing, Const.space8)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 120.0, minHeight: 25.0)
        .padding(.vertical, Const.space2)
        .background(
            RoundedRectangle(cornerRadius: Const.settingsRadius)
                .fill(colorScheme == .dark ? Const.darkBackground : .white)
                .overlay(
                    RoundedRectangle(cornerRadius: Const.settingsRadius)
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
            key: "shortcutRecorder"
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

        let functionKeyCodes: Set<UInt16> = [
            0x7A, 0x78, 0x63, 0x76, 0x60, 0x61,
            0x62, 0x64, 0x65, 0x6D, 0x67, 0x6F,
        ]
        let isFunctionKey = functionKeyCodes.contains(keyCode)

        if modifiers.isEmpty, !isFunctionKey {
            return event
        }

        let specialMap: [UInt16: String] = [
            KeyCode.delete: "⌫",
            0x75: "⌦",
            KeyCode.return: "↩",
            KeyCode.keypadEnter: "⌅",
            KeyCode.space: "Space",
            KeyCode.tab: "⇥",
            KeyCode.leftArrow: "←",
            KeyCode.rightArrow: "→",
            KeyCode.downArrow: "↓",
            KeyCode.upArrow: "↑",
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5",
            0x61: "F6", 0x62: "F7", 0x64: "F8", 0x65: "F9", 0x6D: "F10",
            0x67: "F11", 0x6F: "F12",
        ]

        let displayKey: String = if let special = specialMap[keyCode] {
            special
        } else if let eventChars = event.charactersIgnoringModifiers,
                  !eventChars.isEmpty,
                  eventChars.unicodeScalars.allSatisfy({ $0.value >= 32 })
        {
            eventChars.uppercased()
        } else {
            keyCodeToDisplayString(keyCode)
        }

        guard !displayKey.isEmpty else {
            return event
        }

        shortcut = KeyboardShortcut(
            modifiersRawValue: modifiers.rawValue,
            keyCode: keyCode,
            displayKey: displayKey
        )

        stopRecording()
        save()
        return nil
    }

    private func keyCodeToDisplayString(_ keyCode: UInt16) -> String {
        let keyCodeMap: [UInt16: String] = [
            KeyCode.a: "A", KeyCode.b: "B", KeyCode.c: "C", KeyCode.d: "D",
            KeyCode.e: "E", KeyCode.f: "F", KeyCode.g: "G", KeyCode.h: "H",
            KeyCode.i: "I", KeyCode.j: "J", KeyCode.k: "K", KeyCode.l: "L",
            KeyCode.m: "M", KeyCode.n: "N", KeyCode.o: "O", KeyCode.p: "P",
            KeyCode.q: "Q", KeyCode.r: "R", KeyCode.s: "S", KeyCode.t: "T",
            KeyCode.u: "U", KeyCode.v: "V", KeyCode.w: "W", KeyCode.x: "X",
            KeyCode.y: "Y", KeyCode.z: "Z",
            KeyCode.zero: "0", KeyCode.one: "1", KeyCode.two: "2",
            KeyCode.three: "3", KeyCode.four: "4", KeyCode.five: "5",
            KeyCode.six: "6", KeyCode.seven: "7", KeyCode.eight: "8",
            KeyCode.nine: "9",
            KeyCode.minus: "-", KeyCode.equal: "=",
            KeyCode.leftBracket: "[", KeyCode.rightBracket: "]",
            KeyCode.backslash: "\\", KeyCode.semicolon: ";",
            KeyCode.quote: "'", KeyCode.comma: ",",
            KeyCode.period: ".", KeyCode.slash: "/", KeyCode.grave: "`",
        ]
        return keyCodeMap[keyCode] ?? ""
    }

    private func save() {
        if shortcut.isEmpty {
            HotKeyManager.shared.deleteHotKey(key: hotKeyId)
        } else {
            if HotKeyManager.shared.getHotKey(key: hotKeyId) != nil {
                HotKeyManager.shared.updateHotKey(
                    key: hotKeyId,
                    shortcut: shortcut,
                    isEnabled: true
                )
            } else {
                HotKeyManager.shared.addHotKey(
                    key: hotKeyId,
                    shortcut: shortcut,
                    isGlobal: hotKeyId == "app_launch"
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
                "app_launch"
            )
        }
    }
    .padding(30)
    .frame(width: 400)
}
