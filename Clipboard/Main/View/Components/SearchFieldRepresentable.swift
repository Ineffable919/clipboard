//
//  SearchFieldRepresentable.swift
//  Clipboard
//
//  Created by crown on 2026/1/14.
//

import AppKit
import SwiftUI

struct SearchFieldRepresentable: NSViewRepresentable {
    @Binding var text: String
    var isFocused: Bool
    var onFocusGained: () -> Void
    var onFocusLost: () -> Void

    func makeNSView(context: Context) -> PasteSearchField {
        let field = PasteSearchField()
        field.placeholderString = String(localized: .search)
        field.delegate = context.coordinator
        field.cell?.sendsActionOnEndEditing = false
        context.coordinator.field = field
        return field
    }

    func updateNSView(_ nsView: PasteSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        let isEditing = nsView.currentEditor() != nil

        if isFocused, !isEditing, !context.coordinator.focusSetByExternal {
            context.coordinator.focusSetByExternal = true
            Task { @MainActor in
                nsView.window?.makeFirstResponder(nsView)
            }
        } else if !isFocused, isEditing, context.coordinator.focusSetByExternal {
            context.coordinator.focusSetByExternal = false
            Task { @MainActor in
                nsView.window?.makeFirstResponder(nil)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchFieldRepresentable
        weak var field: PasteSearchField?
        var focusSetByExternal = false

        private var wasFocused = false
        private var windowObservation: NSKeyValueObservation?

        init(_ parent: SearchFieldRepresentable) {
            self.parent = parent
        }

        func startObserving(window: NSWindow?) {
            windowObservation = nil
            guard let window else { return }
            windowObservation = window.observe(\.firstResponder, options: [.new]) { [weak self] win, _ in
                MainActor.assumeIsolated {
                    self?.checkFocus(in: win)
                }
            }
            checkFocus(in: window)
        }

        private func checkFocus(in window: NSWindow) {
            guard let field else { return }
            let responder = window.firstResponder
            let isFocusedNow = responder === field || responder === field.currentEditor()

            if isFocusedNow, !wasFocused {
                wasFocused = true
                parent.onFocusGained()
            } else if !isFocusedNow, wasFocused {
                wasFocused = false
                focusSetByExternal = false
                parent.onFocusLost()
            }
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }
    }
}

final class PasteSearchField: NSSearchField {
    var onMovedToWindow: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onMovedToWindow?(window)
    }

    override var canBecomeKeyView: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        true
    }
}
