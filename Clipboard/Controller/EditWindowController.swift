//
//  EditWindowController.swift
//  Clipboard
//
//  Created by crown on 2025/12/28.
//

import AppKit
import SwiftUI

@MainActor
final class EditWindowController: NSWindowController {
    static let shared = EditWindowController()

    private static let windowWidth: CGFloat = 500.0
    private static let windowHeight: CGFloat = 400.0
    private static let minWidth: CGFloat = 400.0
    private static let minHeight: CGFloat = 300.0

    private(set) var currentModel: PasteboardModel?

    private var editState: EditWindowState?

    var onSave: ((PasteboardModel, NSAttributedString) -> Void)?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Self.minWidth,
                height: Self.minHeight
            ),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView,
            ],
            backing: .buffered,
            defer: false
        )

        window.level = .normal
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarSeparatorStyle = .none
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: Self.minWidth, height: Self.minHeight)

        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        super.init(window: window)

        setupKeyboardShortcuts()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    func openWindow(with model: PasteboardModel) {
        guard model.pasteboardType.isText() else {
            log.warn("Cannot edit non-text model")
            return
        }

        currentModel = model
        editState = EditWindowState(model: model)

        if let state = editState {
            let editView = TextEditView(
                state: state,
                onCancel: { [weak self] in
                    self?.closeWindow()
                },
                onSave: { [weak self] content in
                    self?.saveContent(content)
                }
            )
            window?.contentView = NSHostingView(rootView: editView)
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func closeWindow() {
        window?.orderOut(nil)
        currentModel = nil
        editState = nil
    }

    private func saveFromState() {
        guard let state = editState else {
            return
        }
        saveContent(state.editedContent)
    }

    func saveContent(_ content: NSAttributedString) {
        guard let model = currentModel else {
            return
        }

        let plainText = content.string
        let length = content.length

        let newData: Data = if model.pasteboardType == .string {
            plainText.data(using: .utf8) ?? Data()
        } else {
            content.toData(with: model.pasteboardType) ?? Data()
        }

        let showAttr =
            length > 250
                ? content.attributedSubstring(
                    from: NSRange(location: 0, length: 250)
                )
                : content
        let showData = showAttr.toData(with: model.pasteboardType)

        let newTag = PasteboardModel.calculateTag(
            type: model.pasteboardType,
            content: newData
        )

        Task {
            await PasteDataStore.main.updateItemContent(
                id: model.id!,
                newData: newData,
                newShowData: showData,
                newSearchText: plainText,
                newLength: length,
                newTag: newTag
            )

            await MainActor.run {
                self.closeWindow()
            }
        }
    }

    // MARK: - Private Methods

    private func setupKeyboardShortcuts() {
        EventDispatcher.shared.registerHandler(
            matching: .keyDown,
            key: "editWindow"
        ) { [weak self] event in
            guard event.window === EditWindowController.shared.window else {
                return event
            }

            let keyChar = event.charactersIgnoringModifiers?.lowercased() ?? ""
            let modifiers = event.modifierFlags.intersection([
                .command, .option, .control, .shift,
            ])

            // Cmd+W 关闭窗口
            if modifiers == .command, keyChar == "w" {
                Task { @MainActor in
                    self?.closeWindow()
                }
                return nil
            }

            // Cmd+S 保存
            if modifiers == .command, keyChar == "s" {
                Task { @MainActor in
                    self?.saveFromState()
                }
                return nil
            }

            // Cmd+M 最小化
            if modifiers == .command, keyChar == "m" {
                if self?.window?.isKeyWindow == true {
                    self?.window?.miniaturize(nil)
                    return nil
                }
            }

            // Escape 关闭窗口
            if event.keyCode == KeyCode.escape {
                Task { @MainActor in
                    self?.closeWindow()
                }
                return nil
            }

            if EventDispatcher.shared.handleSystemEditingCommand(event) {
                return nil
            }

            return event
        }
    }
}
