//
//  ClipWindowView.swift
//  clipboard
//
//  Created by crown on 2025/9/11.
//

import Cocoa

final class ClipWindowView: NSPanel {
    func configureCommonSettings() {
        backgroundColor = .clear
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        titlebarSeparatorStyle = .none

        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        configureWindowSharing(
            showDuringScreenShare: PasteUserDefaults.showDuringScreenShare
        )
    }

    func configureWindowSharing(showDuringScreenShare: Bool) {
        sharingType = showDuringScreenShare ? .readOnly : .none
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) {
            return true
        }

        // nonactivatingPanel 不激活菜单栏，需要手动派发编辑命令
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.command),
              !modifiers.contains(.option),
              !modifiers.contains(.control)
        else {
            return false
        }

        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let isShift = modifiers.contains(.shift)

        let action: Selector? = switch key {
        case "c": #selector(NSText.copy(_:))
        case "v": #selector(NSText.paste(_:))
        case "x": #selector(NSText.cut(_:))
        case "a": #selector(NSResponder.selectAll(_:))
        case "z": isShift ? Selector(("redo:")) : Selector(("undo:"))
        default: nil
        }

        guard let action else { return false }
        return NSApp.sendAction(action, to: nil, from: nil)
    }
}
