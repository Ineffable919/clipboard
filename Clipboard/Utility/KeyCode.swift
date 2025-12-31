//
//  KeyCode.swift
//  Clipboard
//
//  Created by crown on 2025/11/25.
//

import AppKit
import Carbon
import Foundation
import SwiftUI

/// 键盘按键代码常量和按键处理工具
/// 提供易读的按键代码定义和按键事件处理功能
enum KeyCode {
    // MARK: - 字母键

    static let a: UInt16 = .init(kVK_ANSI_A) // 0x00
    static let b: UInt16 = .init(kVK_ANSI_B) // 0x0B
    static let c: UInt16 = .init(kVK_ANSI_C) // 0x08
    static let d: UInt16 = .init(kVK_ANSI_D) // 0x02
    static let e: UInt16 = .init(kVK_ANSI_E) // 0x0E
    static let f: UInt16 = .init(kVK_ANSI_F) // 0x03
    static let g: UInt16 = .init(kVK_ANSI_G) // 0x05
    static let h: UInt16 = .init(kVK_ANSI_H) // 0x04
    static let i: UInt16 = .init(kVK_ANSI_I) // 0x22
    static let j: UInt16 = .init(kVK_ANSI_J) // 0x26
    static let k: UInt16 = .init(kVK_ANSI_K) // 0x28
    static let l: UInt16 = .init(kVK_ANSI_L) // 0x25
    static let m: UInt16 = .init(kVK_ANSI_M) // 0x2E
    static let n: UInt16 = .init(kVK_ANSI_N) // 0x2D
    static let o: UInt16 = .init(kVK_ANSI_O) // 0x1F
    static let p: UInt16 = .init(kVK_ANSI_P) // 0x23
    static let q: UInt16 = .init(kVK_ANSI_Q) // 0x0C
    static let r: UInt16 = .init(kVK_ANSI_R) // 0x0F
    static let s: UInt16 = .init(kVK_ANSI_S) // 0x01
    static let t: UInt16 = .init(kVK_ANSI_T) // 0x11
    static let u: UInt16 = .init(kVK_ANSI_U) // 0x20
    static let v: UInt16 = .init(kVK_ANSI_V) // 0x09
    static let w: UInt16 = .init(kVK_ANSI_W) // 0x0D
    static let x: UInt16 = .init(kVK_ANSI_X) // 0x07
    static let y: UInt16 = .init(kVK_ANSI_Y) // 0x10
    static let z: UInt16 = .init(kVK_ANSI_Z) // 0x06

    // MARK: - 数字键

    static let zero: UInt16 = .init(kVK_ANSI_0) // 0x1D
    static let one: UInt16 = .init(kVK_ANSI_1) // 0x12
    static let two: UInt16 = .init(kVK_ANSI_2) // 0x13
    static let three: UInt16 = .init(kVK_ANSI_3) // 0x14
    static let four: UInt16 = .init(kVK_ANSI_4) // 0x15
    static let five: UInt16 = .init(kVK_ANSI_5) // 0x17
    static let six: UInt16 = .init(kVK_ANSI_6) // 0x16
    static let seven: UInt16 = .init(kVK_ANSI_7) // 0x1A
    static let eight: UInt16 = .init(kVK_ANSI_8) // 0x1C
    static let nine: UInt16 = .init(kVK_ANSI_9) // 0x19

    // MARK: - 功能键

    static let escape: UInt16 = .init(kVK_Escape) // 0x35
    static let delete: UInt16 = .init(kVK_Delete) // 0x33
    static let tab: UInt16 = .init(kVK_Tab) // 0x30
    static let `return`: UInt16 = .init(kVK_Return) // 0x24
    static let space: UInt16 = .init(kVK_Space) // 0x31

    // MARK: - 箭头键

    static let leftArrow: UInt16 = .init(kVK_LeftArrow) // 0x7B
    static let rightArrow: UInt16 = .init(kVK_RightArrow) // 0x7C
    static let upArrow: UInt16 = .init(kVK_UpArrow) // 0x7E
    static let downArrow: UInt16 = .init(kVK_DownArrow) // 0x7D

    // MARK: - 符号键

    static let minus: UInt16 = .init(kVK_ANSI_Minus) // 0x1B
    static let equal: UInt16 = .init(kVK_ANSI_Equal) // 0x18
    static let leftBracket: UInt16 = .init(kVK_ANSI_LeftBracket) // 0x21
    static let rightBracket: UInt16 = .init(kVK_ANSI_RightBracket) // 0x1E
    static let backslash: UInt16 = .init(kVK_ANSI_Backslash) // 0x2A
    static let semicolon: UInt16 = .init(kVK_ANSI_Semicolon) // 0x29
    static let quote: UInt16 = .init(kVK_ANSI_Quote) // 0x27
    static let comma: UInt16 = .init(kVK_ANSI_Comma) // 0x2B
    static let period: UInt16 = .init(kVK_ANSI_Period) // 0x2F
    static let slash: UInt16 = .init(kVK_ANSI_Slash) // 0x2C
    static let grave: UInt16 = .init(kVK_ANSI_Grave) // 0x32

    // MARK: - 小键盘

    static let keypadDecimal: UInt16 = .init(kVK_ANSI_KeypadDecimal) // 0x41
    static let keypadMultiply: UInt16 = .init(kVK_ANSI_KeypadMultiply) // 0x43
    static let keypadPlus: UInt16 = .init(kVK_ANSI_KeypadPlus) // 0x45
    static let keypadClear: UInt16 = .init(kVK_ANSI_KeypadClear) // 0x47
    static let keypadDivide: UInt16 = .init(kVK_ANSI_KeypadDivide) // 0x4B
    static let keypadEnter: UInt16 = .init(kVK_ANSI_KeypadEnter) // 0x4C
    static let keypadMinus: UInt16 = .init(kVK_ANSI_KeypadMinus) // 0x4E
    static let keypadEquals: UInt16 = .init(kVK_ANSI_KeypadEquals) // 0x51
    static let keypad0: UInt16 = .init(kVK_ANSI_Keypad0) // 0x52
    static let keypad1: UInt16 = .init(kVK_ANSI_Keypad1) // 0x53
    static let keypad2: UInt16 = .init(kVK_ANSI_Keypad2) // 0x54
    static let keypad3: UInt16 = .init(kVK_ANSI_Keypad3) // 0x55
    static let keypad4: UInt16 = .init(kVK_ANSI_Keypad4) // 0x56
    static let keypad5: UInt16 = .init(kVK_ANSI_Keypad5) // 0x57
    static let keypad6: UInt16 = .init(kVK_ANSI_Keypad6) // 0x58
    static let keypad7: UInt16 = .init(kVK_ANSI_Keypad7) // 0x59
    static let keypad8: UInt16 = .init(kVK_ANSI_Keypad8) // 0x5B
    static let keypad9: UInt16 = .init(kVK_ANSI_Keypad9) // 0x5C

    // MARK: - 可打印字符集合

    /// 所有可打印字符的按键代码集合
    static let printableKeyCodes: Set<Int> = [
        // 字母键
        kVK_ANSI_A, kVK_ANSI_B, kVK_ANSI_C, kVK_ANSI_D, kVK_ANSI_E, kVK_ANSI_F,
        kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_I, kVK_ANSI_J, kVK_ANSI_K, kVK_ANSI_L,
        kVK_ANSI_M, kVK_ANSI_N, kVK_ANSI_O, kVK_ANSI_P, kVK_ANSI_Q, kVK_ANSI_R,
        kVK_ANSI_S, kVK_ANSI_T, kVK_ANSI_U, kVK_ANSI_V, kVK_ANSI_W, kVK_ANSI_X,
        kVK_ANSI_Y, kVK_ANSI_Z,
        // 数字键
        kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4,
        kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
        // 符号键
        kVK_ANSI_Equal, kVK_ANSI_Minus, kVK_ANSI_RightBracket,
        kVK_ANSI_LeftBracket,
        kVK_ANSI_Quote, kVK_ANSI_Semicolon, kVK_ANSI_Backslash, kVK_ANSI_Comma,
        kVK_ANSI_Slash, kVK_ANSI_Period, kVK_ANSI_Grave,
        // 小键盘
        kVK_ANSI_KeypadDecimal, kVK_ANSI_KeypadMultiply, kVK_ANSI_KeypadPlus,
        kVK_ANSI_KeypadClear, kVK_ANSI_KeypadDivide, kVK_ANSI_KeypadEnter,
        kVK_ANSI_KeypadMinus, kVK_ANSI_KeypadEquals,
        kVK_ANSI_Keypad0, kVK_ANSI_Keypad1, kVK_ANSI_Keypad2, kVK_ANSI_Keypad3,
        kVK_ANSI_Keypad4, kVK_ANSI_Keypad5, kVK_ANSI_Keypad6, kVK_ANSI_Keypad7,
        kVK_ANSI_Keypad8, kVK_ANSI_Keypad9,
    ]

    // MARK: - 按键判断

    /// 检查键码是否为可打印字符
    static func isPrintableCharacter(_ keyCode: Int) -> Bool {
        printableKeyCodes.contains(keyCode)
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
        let modifier = modifierFlags(from: PasteUserDefaults.quickPasteModifier)
        return NSEvent.modifierFlags.contains(modifier)
    }
}
