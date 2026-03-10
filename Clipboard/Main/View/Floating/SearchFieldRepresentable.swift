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

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "搜索"
        field.delegate = context.coordinator
        field.bezelStyle = .roundedBezel
        field.cell?.sendsActionOnEndEditing = false
        context.coordinator.field = field
        context.coordinator.startObservingFocus()
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        let isEditing = nsView.currentEditor() != nil

        if isFocused, !isEditing {
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
        weak var field: NSSearchField?
        var focusSetByExternal = false

        private var wasFocused = false
        private nonisolated(unsafe) var windowObserver: Any?

        init(_ parent: SearchFieldRepresentable) {
            self.parent = parent
        }

        deinit {
            if let observer = windowObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func startObservingFocus() {
            windowObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didUpdateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.checkFocusState()
                }
            }
        }

        private func checkFocusState() {
            guard let field else { return }
            let isFocusedNow = field.currentEditor() != nil

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
