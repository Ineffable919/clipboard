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

// MARK: - 快捷键管理器

@MainActor
class HotKeyManager {
    static let shared = HotKeyManager()

    /// 'CLIP' four-char code；Carbon EventHotKeyID.signature 标识本 app。
    static let hotKeySignature: OSType = 0x434C_4950

    struct Registration {
        let key: String
        let id: UInt32
        let ref: EventHotKeyRef
    }

    var registrationsByID: [UInt32: Registration] = [:]
    var registrationsByKey: [String: Registration] = [:]
    var nextHotKeyID: UInt32 = 1

    var handlers: [String: () -> Void] = [:]

    /// 边沿过滤：macOS 14 上 Carbon 会按 key-repeat 速率派发多次 Pressed，
    /// 只在"从未按下 → 按下"的瞬间触发 handler，直到 Released 才解除。
    var pressedKeys: Set<String> = []

    var isInitialized = false
    var eventHandlerRef: EventHandlerRef?

    private init() {
        registerBuiltInHandlers()
        installGlobalEventHandler()
    }

    func registerBuiltInHandlers() {
        handlers["app_launch"] = {
            WindowManager.shared.toggleWindow(frame: NSScreen.main?.frame)
        }
    }

    // MARK: - 生命周期

    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true
        migrateHotKeysIfNeeded()
        loadHotKeys()
    }

    func migrateHotKeysIfNeeded() {
        var hotKeyList = getAllHotKeys()
        var needsSave = false

        if !hotKeyList.contains(where: { $0.key == "previous_tab" }) {
            hotKeyList.append(HotKeyInfo(
                key: "previous_tab",
                shortcut: KeyboardShortcut(
                    modifiersRawValue: NSEvent.ModifierFlags.command.rawValue,
                    keyCode: KeyCode.leftArrow,
                    displayKey: "←"
                ),
                isEnabled: true,
                isGlobal: false
            ))
            needsSave = true
            log.info("新增 previous_tab 默认快捷键")
        }

        if !hotKeyList.contains(where: { $0.key == "next_tab" }) {
            hotKeyList.append(HotKeyInfo(
                key: "next_tab",
                shortcut: KeyboardShortcut(
                    modifiersRawValue: NSEvent.ModifierFlags.command.rawValue,
                    keyCode: KeyCode.rightArrow,
                    displayKey: "→"
                ),
                isEnabled: true,
                isGlobal: false
            ))
            needsSave = true
            log.info("新增 next_tab 默认快捷键")
        }

        if needsSave {
            saveHotKeys(hotKeyList)
        }
    }

    func clear() {
        unregisterAllHotKeys()
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
        log.debug("HotKeyManager 已清理所有快捷键")
    }

    func loadHotKeys() {
        for info in getAllHotKeys() where info.isEnabled && info.isGlobal {
            if let handler = handlers[info.key] {
                registerSystemHotKey(info: info, handler: handler)
            }
        }
    }

    func getAllHotKeys() -> [HotKeyInfo] {
        PasteUserDefaults.globalHotKeys
    }

    func saveHotKeys(_ hotKeys: [HotKeyInfo]) {
        PasteUserDefaults.globalHotKeys = hotKeys
    }

    // MARK: - CRUD

    @discardableResult
    func addHotKey(
        key: String,
        shortcut: KeyboardShortcut,
        isGlobal: Bool = true
    ) -> HotKeyInfo? {
        guard !shortcut.isEmpty else { return nil }

        var hotKeyList = getAllHotKeys()

        if let conflict = hotKeyList.first(where: { $0.shortcut == shortcut || $0.key == key }) {
            if conflict.key == key {
                log.debug("快捷键 key 已存在: \(key)")
            } else {
                log.debug("快捷键组合已被 \(conflict.key) 占用")
            }
            return nil
        }

        let info = HotKeyInfo(key: key, shortcut: shortcut, isEnabled: true, isGlobal: isGlobal)
        hotKeyList.append(info)
        saveHotKeys(hotKeyList)

        if isGlobal {
            guard let handler = handlers[key] else {
                log.warn("快捷键 \(key) 没有对应的内置 handler")
                return nil
            }
            registerSystemHotKey(info: info, handler: handler)
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

        if let otherIndex = hotKeyList.firstIndex(where: { $0.key != key && $0.shortcut == newShortcut }) {
            log.warn("快捷键组合与 \(hotKeyList[otherIndex].key) 冲突")
            return nil
        }

        let newInfo = HotKeyInfo(
            key: key,
            shortcut: newShortcut,
            isEnabled: isEnabled ?? oldInfo.isEnabled,
            isGlobal: oldInfo.isGlobal
        )
        hotKeyList[index] = newInfo
        saveHotKeys(hotKeyList)

        if newInfo.isGlobal {
            unregisterSystemHotKey(key: key)
            if newInfo.isEnabled, let handler = handlers[key] {
                registerSystemHotKey(info: newInfo, handler: handler)
            }
        }

        return newInfo
    }

    func deleteHotKey(key: String) {
        var hotKeyList = getAllHotKeys()
        if hotKeyList.first(where: { $0.key == key })?.isGlobal == true {
            unregisterSystemHotKey(key: key)
        }
        hotKeyList.removeAll(where: { $0.key == key })
        saveHotKeys(hotKeyList)
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
                    modifiersRawValue: NSEvent.ModifierFlags([.command, .shift]).rawValue,
                    keyCode: KeyCode.keyV,
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
            )
        ]

        saveHotKeys(defaultHotKeys)

        for info in defaultHotKeys where info.isEnabled && info.isGlobal {
            if let handler = handlers[info.key] {
                registerSystemHotKey(info: info, handler: handler)
            }
        }

        PasteUserDefaults.quickPasteModifier = 0
        PasteUserDefaults.plainTextModifier = 3

        log.info("已重置所有快捷键为默认值")
    }
}
