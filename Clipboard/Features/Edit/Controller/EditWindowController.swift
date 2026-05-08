//
//  EditWindowController.swift
//  Clipboard
//
//  Created by crown on 2025/12/28.
//

import AppKit
import SwiftUI

@MainActor
final class EditWindowController: NSWindowController, NSWindowDelegate {
    static let shared = EditWindowController()

    private static let minWidth: CGFloat = 400.0
    private static let minHeight: CGFloat = 300.0

    private(set) var currentModel: PasteboardModel?

    private var editState: EditWindowState?

    var onSave: ((PasteboardModel, NSAttributedString) -> Void)?

    private init() {
        let window = EditWindow(
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

        window.delegate = self
        window.onKeyEquivalent = { [weak self] event in
            self?.handleKeyEquivalent(event) ?? false
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var isNewItem: Bool = false

    // MARK: - Public Methods

    func openNewWindow() {
        let appName = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleName"
        ) as? String ?? "Clipboard"

        let emptyModel = PasteboardModel(
            pasteboardType: .string,
            data: Data(),
            showData: nil,
            timestamp: Int64(Date().timeIntervalSince1970),
            appPath: Bundle.main.bundlePath,
            appName: appName,
            searchText: "",
            length: 0,
            group: -1,
            tag: "string"
        )

        isNewItem = true
        currentModel = emptyModel
        editState = EditWindowState(model: emptyModel)

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

    func openWindow(with model: PasteboardModel) {
        guard model.pasteboardType.isText() else {
            log.warn("Cannot edit non-text model")
            return
        }

        isNewItem = false
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
        isNewItem = false
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_: Notification) {
        currentModel = nil
        editState = nil
        isNewItem = false
    }

    private func saveFromState() {
        guard let state = editState else {
            return
        }
        saveContent(state.currentContent)
    }

    func saveContent(_ content: NSAttributedString) {
        guard let model = currentModel else {
            return
        }

        let plainText = content.string
        guard !plainText.allSatisfy(\.isWhitespace) else {
            closeWindow()
            return
        }

        let length = content.length
        let isRich = Self.hasRichTextAttributes(content)
        let actualType: PasteboardType = isRich ? .rtf : .string

        let newData: Data = if actualType == .string {
            plainText.data(using: .utf8) ?? Data()
        } else {
            content.toData(with: actualType) ?? Data()
        }

        let showAttr =
            length > 250
                ? content.attributedSubstring(
                    from: NSRange(location: 0, length: 250)
                )
                : content
        let showData = showAttr.toData(with: actualType)

        let newTag = PasteboardModel.calculateTag(
            type: actualType,
            content: newData
        )

        if isNewItem {
            let newModel = PasteboardModel(
                pasteboardType: actualType,
                data: newData,
                showData: showData,
                timestamp: Int64(Date().timeIntervalSince1970),
                appPath: model.appPath,
                appName: model.appName,
                searchText: PasteboardModel.normalizeSearchText(plainText),
                length: length,
                group: -1,
                tag: newTag
            )

            Task {
                await PasteDataStore.main.insertModel(newModel)
                await MainActor.run {
                    self.closeWindow()
                }
            }
        } else {
            guard let itemId = model.id else { return }

            Task {
                await PasteDataStore.main.updateItemContent(
                    id: itemId,
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
    }

    /// 检测 NSAttributedString 是否包含富文本属性（加粗、斜体、下划线、删除线等）
    private static func hasRichTextAttributes(
        _ attributedString: NSAttributedString
    ) -> Bool {
        guard attributedString.length > 0 else { return false }

        let fullRange = NSRange(location: 0, length: attributedString.length)
        var found = false

        attributedString.enumerateAttributes(
            in: fullRange,
            options: []
        ) { attributes, _, stop in
            // 检查下划线
            if let underline = attributes[.underlineStyle] as? Int,
               underline != 0
            {
                found = true
                stop.pointee = true
                return
            }

            // 检查删除线
            if let strikethrough = attributes[.strikethroughStyle] as? Int,
               strikethrough != 0
            {
                found = true
                stop.pointee = true
                return
            }

            // 检查字体特征（加粗、斜体）
            if let font = attributes[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.bold) || traits.contains(.italic) {
                    found = true
                    stop.pointee = true
                    return
                }
            }
        }

        return found
    }

    // MARK: - Private Methods

    private func handleKeyEquivalent(_ event: NSEvent) -> Bool {
        let keyChar = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let modifiers = event.modifierFlags.intersection([
            .command, .option, .control, .shift,
        ])

        // Cmd+W — close window
        if modifiers == .command, keyChar == "w" {
            closeWindow()
            return true
        }

        // Cmd+S — save
        if modifiers == .command, keyChar == "s" {
            saveFromState()
            return true
        }

        // Cmd+M — minimise
        if modifiers == .command, keyChar == "m" {
            window?.miniaturize(nil)
            return true
        }

        // Escape — close window
        if event.keyCode == KeyCode.escape {
            closeWindow()
            return true
        }

        return false
    }
}
