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

// MARK: - 存储快捷键模型

struct HotKeyInfo: Codable, Identifiable, Equatable {
    let key: String
    let shortcut: KeyboardShortcut
    let isEnabled: Bool
    let isGlobal: Bool

    var id: String { key }

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

    private var hotKeys: [String: EventHotKeyRef?] = [:]
    // 快捷键映射
    private var handlers: [String: () -> Void] = [:]
    private var isInitialized = false
    private var eventHandlerRef: EventHandlerRef?

    private init() {
        registerBuiltInHandlers()
        installGlobalEventHandler()
    }

    private func registerBuiltInHandlers() {
        handlers["app_launch"] = {
            ClipMainWindowController.shared.toggleWindow()
        }
    }

    private func installGlobalEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed),
        )

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
                    &hotKeyID,
                )

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData!)
                    .takeUnretainedValue()

                let receivedHash = Int(truncatingIfNeeded: hotKeyID.signature)
                if let handler = manager.handlers.first(where: { key, _ in
                    let keyHash = abs(key.hashValue) % Int(UInt32.max)
                    return keyHash == receivedHash
                })?.value {
                    DispatchQueue.main.async {
                        handler()
                    }
                }

                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef,
        )

        log.debug("全局快捷键事件处理器初始化完成")
    }

    // MARK: - 生命周期

    func initialize() {
        guard !isInitialized else {
            return
        }

        isInitialized = true
        loadHotKeys()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil,
        )

        log.info("HotKeyManager 初始化完成")
    }

    @objc private func applicationWillTerminate() {
        unregisterAllHotKeys()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }

        log.debug("HotKeyManager 已清理所有快捷键")
    }

    private func loadHotKeys() {
        let infos = getAllHotKeys()
        for info in infos where info.isEnabled {
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
    ) -> HotKeyInfo? {
        guard !shortcut.isEmpty else {
            return nil
        }

        var hotKeyList = getAllHotKeys()

        if let conflict = hotKeyList.first(where: { $0.shortcut == shortcut || $0.key == key }) {
            if conflict.key == key {
                log.debug("快捷键 key 已存在: \(key)")
            } else {
                log.debug("快捷键组合已被 \(conflict.key) 占用")
            }
            return nil
        }

        guard let handler = handlers[key] else {
            log.warn("快捷键 \(key) 没有对应的内置 handler")
            return nil
        }

        let info = HotKeyInfo(
            key: key,
            shortcut: shortcut,
            isEnabled: true,
        )
        hotKeyList.append(info)
        saveHotKeys(hotKeyList)

        if registerSystemHotKey(info: info, handler: handler) {
            return info
        }

        return nil
    }

    @discardableResult
    func updateHotKey(
        key: String,
        shortcut: KeyboardShortcut? = nil,
        isEnabled: Bool? = nil,
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
        )

        if let otherIndex = hotKeyList.firstIndex(where: {
            $0.key != key && $0.shortcut == newShortcut
        }) {
            log.debug("快捷键组合与 \(hotKeyList[otherIndex].key) 冲突")
            return nil
        }

        hotKeyList[index] = newInfo
        saveHotKeys(hotKeyList)

        unregisterSystemHotKey(key: key)
        if newInfo.isEnabled, let handler = handlers[key] {
            if registerSystemHotKey(info: newInfo, handler: handler) {
                return newInfo
            }
        }
        return nil
    }

    @discardableResult
    func deleteHotKey(key: String) -> Bool {
        var hotKeyList = getAllHotKeys()
        hotKeyList.removeAll(where: { $0.key == key })
        saveHotKeys(hotKeyList)
        unregisterSystemHotKey(key: key)
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
        handler _: @escaping () -> Void,
    ) -> Bool {
        var hotKeyRef: EventHotKeyRef?

        let hashValue = abs(info.key.hashValue) % Int(UInt32.max)
        let hotKeyID = EventHotKeyID(
            signature: OSType(truncatingIfNeeded: hashValue),
            id: UInt32(truncatingIfNeeded: hashValue),
        )

        let status = RegisterEventHotKey(
            UInt32(info.shortcut.keyCode),
            info.carbonModifierFlags,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef,
        )

        guard status == noErr else {
            log.error("注册快捷键失败: \(info.key), status: \(status)")
            return false
        }

        hotKeys[info.key] = hotKeyRef
        log.info("注册快捷键成功: \(info.key) - \(info.displayText)")
        return true
    }

    /// 注销系统快捷键
    private func unregisterSystemHotKey(key: String) {
        if let hotKeyRef = hotKeys[key], let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeys.removeValue(forKey: key)
            log.info("注销快捷键成功：\(key)")
        }
    }

    private func unregisterAllHotKeys() {
        for key in hotKeys.keys {
            unregisterSystemHotKey(key: key)
        }
    }

    func clearAllHotKeys() {
        unregisterAllHotKeys()
        saveHotKeys([])
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
