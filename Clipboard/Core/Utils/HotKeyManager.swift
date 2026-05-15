//
//  HotKeyManager.swift
//  Clipboard
//
//  Created by crown on 2025/11/24.
//

import AppKit
import Carbon
import Foundation
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

    var isEmpty: Bool {
        displayKey.isEmpty && modifiersRawValue == 0
    }

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

// MARK: - 存储快捷键模型

struct HotKeyInfo: Codable, Identifiable, Equatable {
    let key: String
    let shortcut: KeyboardShortcut
    let isEnabled: Bool
    let isGlobal: Bool

    var id: String {
        key
    }

    init(
        key: String,
        shortcut: KeyboardShortcut,
        isEnabled: Bool = true,
        isGlobal: Bool = true
    ) {
        self.key = key
        self.shortcut = shortcut
        self.isEnabled = isEnabled
        self.isGlobal = isGlobal
    }

    var displayText: String {
        shortcut.displayString
    }

    var carbonModifierFlags: UInt32 {
        shortcut.modifiers.carbonModifierFlags
    }
}

// MARK: - 快捷键管理器

class HotKeyManager {
    static let shared = HotKeyManager()

    /// 'CLIP' four-char code; Carbon EventHotKeyID.signature 标识本 app。
    private static let hotKeySignature: OSType = 0x434C_4950

    private struct Registration {
        let key: String
        let id: UInt32
        let ref: EventHotKeyRef
    }

    private var registrationsByID: [UInt32: Registration] = [:]
    private var registrationsByKey: [String: Registration] = [:]
    private var nextHotKeyID: UInt32 = 1

    private var handlers: [String: () -> Void] = [:]

    /// 边沿过滤：macOS 14 上 Carbon 会按 key-repeat 速率派发多次 Pressed，
    /// 只在"从未按下 → 按下"的瞬间触发 handler，直到 Released 才解除。
    private var pressedKeys: Set<String> = []

    private var isInitialized = false
    private var eventHandlerRef: EventHandlerRef?

    private init() {
        registerBuiltInHandlers()
        installGlobalEventHandler()
    }

    private func registerBuiltInHandlers() {
        handlers["app_launch"] = {
            WindowManager.shared.toggleWindow(frame: NSScreen.main?.frame)
        }
    }

    private func installGlobalEventHandler() {
        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            ),
        ]

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    UInt32(kEventParamDirectObject),
                    UInt32(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData!)
                    .takeUnretainedValue()

                guard let reg = manager.registrationsByID[hotKeyID.id] else {
                    return noErr
                }

                let kind = GetEventKind(event)
                if kind == UInt32(kEventHotKeyReleased) {
                    manager.pressedKeys.remove(reg.key)
                    return noErr
                }

                // kEventHotKeyPressed：只在"从未按下 → 按下"边沿触发。
                // 后续的 auto-repeat Pressed 事件直到收到 Released 之前一律丢弃。
                guard !manager.pressedKeys.contains(reg.key) else {
                    return noErr
                }
                manager.pressedKeys.insert(reg.key)
                manager.handlers[reg.key]?()
                return noErr
            },
            2,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        log.debug("全局快捷键事件处理器初始化完成")
    }

    // MARK: - 生命周期

    func initialize() {
        guard !isInitialized else {
            return
        }

        isInitialized = true
        migrateHotKeysIfNeeded()
        loadHotKeys()
    }

    private func migrateHotKeysIfNeeded() {
        var hotKeyList = getAllHotKeys()
        var needsSave = false

        if !hotKeyList.contains(where: { $0.key == "previous_tab" }) {
            let previousTabInfo = HotKeyInfo(
                key: "previous_tab",
                shortcut: KeyboardShortcut(
                    modifiersRawValue: NSEvent.ModifierFlags.command.rawValue,
                    keyCode: KeyCode.leftArrow,
                    displayKey: "←"
                ),
                isEnabled: true,
                isGlobal: false
            )
            hotKeyList.append(previousTabInfo)
            needsSave = true
            log.info("新增 previous_tab 默认快捷键")
        }

        if !hotKeyList.contains(where: { $0.key == "next_tab" }) {
            let nextTabInfo = HotKeyInfo(
                key: "next_tab",
                shortcut: KeyboardShortcut(
                    modifiersRawValue: NSEvent.ModifierFlags.command.rawValue,
                    keyCode: KeyCode.rightArrow,
                    displayKey: "→"
                ),
                isEnabled: true,
                isGlobal: false
            )
            hotKeyList.append(nextTabInfo)
            needsSave = true
            log.info("新增 next_tab 默认快捷键")
        }

        if needsSave {
            saveHotKeys(hotKeyList)
        }
    }

    func clear() {
        unregisterAllHotKeys()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }

        log.debug("HotKeyManager 已清理所有快捷键")
    }

    private func loadHotKeys() {
        let infos = getAllHotKeys()
        for info in infos where info.isEnabled && info.isGlobal {
            if let handler = handlers[info.key] {
                _ = registerSystemHotKey(info: info, handler: handler)
            }
        }
    }

    func getAllHotKeys() -> [HotKeyInfo] {
        PasteUserDefaults.globalHotKeys
    }

    private func saveHotKeys(_ hotKeys: [HotKeyInfo]) {
        PasteUserDefaults.globalHotKeys = hotKeys
    }

    // MARK: - CRUD

    @discardableResult
    func addHotKey(
        key: String,
        shortcut: KeyboardShortcut,
        isGlobal: Bool = true
    ) -> HotKeyInfo? {
        guard !shortcut.isEmpty else {
            return nil
        }

        var hotKeyList = getAllHotKeys()

        if let conflict = hotKeyList.first(where: {
            $0.shortcut == shortcut || $0.key == key
        }) {
            if conflict.key == key {
                log.debug("快捷键 key 已存在: \(key)")
            } else {
                log.debug("快捷键组合已被 \(conflict.key) 占用")
            }
            return nil
        }

        let info = HotKeyInfo(
            key: key,
            shortcut: shortcut,
            isEnabled: true,
            isGlobal: isGlobal
        )
        hotKeyList.append(info)
        saveHotKeys(hotKeyList)

        if isGlobal {
            guard let handler = handlers[key] else {
                log.warn("快捷键 \(key) 没有对应的内置 handler")
                return nil
            }
            if registerSystemHotKey(info: info, handler: handler) {
                return info
            }
        }

        return info
    }

    @discardableResult
    func updateHotKey(
        key: String,
        shortcut: KeyboardShortcut? = nil,
        isEnabled: Bool? = nil
    ) -> HotKeyInfo? {
        var hotKeyList = getAllHotKeys()
        guard let index = hotKeyList.firstIndex(where: { $0.key == key }) else {
            log.warn("未找到快捷键: \(key)")
            return nil
        }

        let oldInfo = hotKeyList[index]
        let newShortcut = shortcut ?? oldInfo.shortcut

        if let shortcut, shortcut.isEmpty {
            return nil
        }

        let newInfo = HotKeyInfo(
            key: key,
            shortcut: newShortcut,
            isEnabled: isEnabled ?? oldInfo.isEnabled,
            isGlobal: oldInfo.isGlobal
        )

        if let otherIndex = hotKeyList.firstIndex(where: {
            $0.key != key && $0.shortcut == newShortcut
        }) {
            log.debug("快捷键组合与 \(hotKeyList[otherIndex].key) 冲突")
            return nil
        }

        hotKeyList[index] = newInfo
        saveHotKeys(hotKeyList)

        if newInfo.isEnabled, newInfo.isGlobal, let handler = handlers[key] {
            unregisterSystemHotKey(key: key)
            _ = registerSystemHotKey(info: newInfo, handler: handler)
        }

        return newInfo
    }

    @discardableResult
    func deleteHotKey(key: String) -> Bool {
        var hotKeyList = getAllHotKeys()

        if let info = hotKeyList.first(where: { $0.key == key }), info.isGlobal {
            unregisterSystemHotKey(key: key)
        }

        hotKeyList.removeAll(where: { $0.key == key })
        saveHotKeys(hotKeyList)
        return true
    }

    func getHotKey(key: String) -> HotKeyInfo? {
        getAllHotKeys().first(where: { $0.key == key })
    }

    @discardableResult
    func enableHotKey(key: String) -> Bool {
        updateHotKey(key: key, isEnabled: true) != nil
    }

    @discardableResult
    func disableHotKey(key: String) -> Bool {
        updateHotKey(key: key, isEnabled: false) != nil
    }

    // MARK: - 系统快捷键注册

    private func registerSystemHotKey(
        info: HotKeyInfo,
        handler _: @escaping () -> Void
    ) -> Bool {
        // 同一个 key 重新注册时，先清掉旧 ref，避免叠加。
        unregisterSystemHotKey(key: info.key)

        let id = nextHotKeyID
        nextHotKeyID &+= 1
        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: id)

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(info.shortcut.keyCode),
            info.carbonModifierFlags,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let ref = hotKeyRef else {
            log.error("注册快捷键失败: \(info.key), status: \(status)")
            return false
        }

        let reg = Registration(key: info.key, id: id, ref: ref)
        registrationsByID[id] = reg
        registrationsByKey[info.key] = reg
        log.info("注册快捷键成功: \(info.key) - \(info.displayText) (id=\(id))")
        return true
    }

    private func unregisterSystemHotKey(key: String) {
        guard let reg = registrationsByKey.removeValue(forKey: key) else { return }
        registrationsByID.removeValue(forKey: reg.id)
        pressedKeys.remove(key)
        UnregisterEventHotKey(reg.ref)
        log.info("注销快捷键成功：\(key)")
    }

    private func unregisterAllHotKeys() {
        for key in Array(registrationsByKey.keys) {
            unregisterSystemHotKey(key: key)
        }
    }

    func clearAllHotKeys() {
        unregisterAllHotKeys()
        saveHotKeys([])
    }

    func resetToDefaults() {
        unregisterAllHotKeys()

        let defaultHotKeys = [
            HotKeyInfo(
                key: "app_launch",
                shortcut: KeyboardShortcut(
                    modifiersRawValue: NSEvent.ModifierFlags([.command, .shift])
                        .rawValue,
                    keyCode: KeyCode.v,
                    displayKey: "V"
                ),
                isEnabled: true,
                isGlobal: true
            ),
            HotKeyInfo(
                key: "previous_tab",
                shortcut: KeyboardShortcut(
                    modifiersRawValue: NSEvent.ModifierFlags.command.rawValue,
                    keyCode: KeyCode.leftArrow,
                    displayKey: "←"
                ),
                isEnabled: true,
                isGlobal: false
            ),
            HotKeyInfo(
                key: "next_tab",
                shortcut: KeyboardShortcut(
                    modifiersRawValue: NSEvent.ModifierFlags.command.rawValue,
                    keyCode: KeyCode.rightArrow,
                    displayKey: "→"
                ),
                isEnabled: true,
                isGlobal: false
            ),
        ]

        saveHotKeys(defaultHotKeys)

        for info in defaultHotKeys where info.isEnabled && info.isGlobal {
            if let handler = handlers[info.key] {
                _ = registerSystemHotKey(info: info, handler: handler)
            }
        }

        // 重置修饰键设置
        PasteUserDefaults.quickPasteModifier = 0
        PasteUserDefaults.plainTextModifier = 3

        log.info("已重置所有快捷键为默认值")
    }
}

// MARK: - NSEvent.ModifierFlags

extension NSEvent.ModifierFlags {
    var carbonModifierFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) {
            flags |= UInt32(cmdKey)
        }
        if contains(.option) {
            flags |= UInt32(optionKey)
        }
        if contains(.control) {
            flags |= UInt32(controlKey)
        }
        if contains(.shift) {
            flags |= UInt32(shiftKey)
        }
        return flags
    }
}
