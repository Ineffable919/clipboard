import AppKit
import Carbon

extension HotKeyManager {
    func installGlobalEventHandler() {
        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            )
        ]

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData -> OSStatus in
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

    // MARK: - 系统快捷键注册

    @discardableResult
    func registerSystemHotKey(info: HotKeyInfo, handler _: @escaping () -> Void) -> Bool {
        unregisterSystemHotKey(key: info.key)

        repeat {
            nextHotKeyID &+= 1
        } while nextHotKeyID == 0

        let id = nextHotKeyID
        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: id)

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(info.shortcut.keyCode),
            info.shortcut.modifiers.carbonModifierFlags,
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

    func unregisterSystemHotKey(key: String) {
        guard let reg = registrationsByKey.removeValue(forKey: key) else { return }
        registrationsByID.removeValue(forKey: reg.id)
        pressedKeys.remove(key)
        UnregisterEventHotKey(reg.ref)
        log.info("注销快捷键成功：\(key)")
    }

    func unregisterAllHotKeys() {
        for key in Array(registrationsByKey.keys) {
            unregisterSystemHotKey(key: key)
        }
    }

}

// MARK: - NSEvent.ModifierFlags + Carbon

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
