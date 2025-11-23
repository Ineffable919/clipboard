//
//  KeyHelper.swift
//  Clipboard
//
//  Created by wangj on 2025/9/24.
//

import AppKit
import Carbon
import Foundation
import SwiftUI

enum KeyHelper {
    static let numberCharacters: [Int] = [
        kVK_ANSI_A,
        kVK_ANSI_S,
        kVK_ANSI_D,
        kVK_ANSI_F,
        kVK_ANSI_H,
        kVK_ANSI_G,
        kVK_ANSI_Z,
        kVK_ANSI_X,
        kVK_ANSI_C,
        kVK_ANSI_V,
        kVK_ANSI_B,
        kVK_ANSI_Q,
        kVK_ANSI_W,
        kVK_ANSI_E,
        kVK_ANSI_R,
        kVK_ANSI_Y,
        kVK_ANSI_T,
        kVK_ANSI_1,
        kVK_ANSI_2,
        kVK_ANSI_3,
        kVK_ANSI_4,
        kVK_ANSI_6,
        kVK_ANSI_5,
        kVK_ANSI_Equal,
        kVK_ANSI_9,
        kVK_ANSI_7,
        kVK_ANSI_Minus,
        kVK_ANSI_8,
        kVK_ANSI_0,
        kVK_ANSI_RightBracket,
        kVK_ANSI_O,
        kVK_ANSI_U,
        kVK_ANSI_LeftBracket,
        kVK_ANSI_I,
        kVK_ANSI_P,
        kVK_ANSI_L,
        kVK_ANSI_J,
        kVK_ANSI_K,
        kVK_ANSI_N,
        kVK_ANSI_M,
        kVK_ANSI_Period,
        kVK_ANSI_Grave,
        kVK_ANSI_KeypadDecimal,
        kVK_ANSI_KeypadMultiply,
        kVK_ANSI_KeypadPlus,
        kVK_ANSI_KeypadClear,
        kVK_ANSI_KeypadDivide,
        kVK_ANSI_KeypadEnter,
        kVK_ANSI_KeypadMinus,
        kVK_ANSI_KeypadEquals,
        kVK_ANSI_Keypad0,
        kVK_ANSI_Keypad1,
        kVK_ANSI_Keypad2,
        kVK_ANSI_Keypad3,
        kVK_ANSI_Keypad4,
        kVK_ANSI_Keypad5,
        kVK_ANSI_Keypad6,
        kVK_ANSI_Keypad7,
        kVK_ANSI_Keypad8,
        kVK_ANSI_Keypad9,
    ]

    /// 检查键码是否为可打印字符
    static func isPrintableCharacter(_ keyCode: Int) -> Bool {
        numberCharacters.contains(keyCode)
    }

    /// 检查事件是否应该触发搜索
    static func shouldTriggerSearch(for event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags
        let excludedModifiers: NSEvent.ModifierFlags = [
            .command, .control, .option,
        ]

        if modifiers.intersection(excludedModifiers).isEmpty == false {
            return false
        }

        return isPrintableCharacter(Int(event.keyCode))
    }

    // MARK: - 修饰键转换

    /// 将用户设置的修饰键索引转换为 NSEvent.ModifierFlags
    /// - Parameter modifierIndex: 修饰键索引 (0: Command, 1: Option, 2: Control, 3: Shift)
    /// - Returns: 对应的 NSEvent.ModifierFlags
    static func modifierFlags(from modifierIndex: Int) -> NSEvent.ModifierFlags {
        switch modifierIndex {
        case 0: .command
        case 1: .option
        case 2: .control
        case 3: .shift
        default: .shift
        }
    }

    /// 将用户设置的修饰键索引转换为 SwiftUI 的 EventModifiers
    /// - Parameter modifierIndex: 修饰键索引 (0: Command, 1: Option, 2: Control, 3: Shift)
    /// - Returns: 对应的 EventModifiers
    static func eventModifiers(from modifierIndex: Int)
        -> SwiftUI.EventModifiers
    {
        switch modifierIndex {
        case 0: .command
        case 1: .option
        case 2: .control
        case 3: .shift
        default: .shift
        }
    }

    /// 检查事件是否包含指定索引的修饰键
    /// - Parameters:
    ///   - event: NSEvent 事件
    ///   - modifierIndex: 修饰键索引 (0: Command, 1: Option, 2: Control, 3: Shift)
    /// - Returns: 是否包含该修饰键
    static func hasModifier(_ event: NSEvent, modifierIndex: Int) -> Bool {
        let modifier = modifierFlags(from: modifierIndex)
        return event.modifierFlags.contains(modifier)
    }

    /// 检查当前是否按下了指定索引的修饰键
    /// - Parameter modifierIndex: 修饰键索引 (0: Command, 1: Option, 2: Control, 3: Shift)
    /// - Returns: 是否当前按下该修饰键
    static func isModifierPressed(modifierIndex: Int) -> Bool {
        let modifier = modifierFlags(from: modifierIndex)
        return NSEvent.modifierFlags.contains(modifier)
    }

    /// 检查当前是否按下了快速粘贴的修饰键
    /// - Returns: 是否按下了 quickPasteModifier 对应的修饰键
    static func isQuickPasteModifierPressed() -> Bool {
        isModifierPressed(modifierIndex: PasteUserDefaults.quickPasteModifier)
    }
}
