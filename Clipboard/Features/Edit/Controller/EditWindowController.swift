//
//  EditWindowController.swift
//  Clipboard
//
//  Created by crown on 2025/12/28.
//

import AppKit

@MainActor
final class EditWindowController: NSWindowController, NSWindowDelegate {
    static let shared = EditWindowController()

    private static let minWidth: CGFloat = 400.0
    private static let minHeight: CGFloat = 300.0
    private static let jsonWidth: CGFloat = 800.0
    private static let jsonHeight: CGFloat = 600.0
    private static let modeResizeDuration = 0.18

    private(set) var currentModel: PasteboardModel?

    private var editContentView: EditContentView?
    private var stableWindowCenter: NSPoint?
    private var resizeGeneration = 0
    private var isResizingForMode = false
    private var needsInitialPresentation = false

    var onSave: ((PasteboardModel, EditedContent) -> Void)?

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

        stableWindowCenter = Self.center(of: window.frame)
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
        needsInitialPresentation = true
        installContentView(for: emptyModel)
    }

    func openWindow(with model: PasteboardModel) {
        guard model.pasteboardType.isText() else {
            log.warn("Cannot edit non-text model")
            return
        }

        isNewItem = false
        currentModel = model
        needsInitialPresentation = true
        installContentView(for: model)
    }

    private func installContentView(for model: PasteboardModel) {
        let contentView = EditContentView(model: model)
        contentView.onCancel = { [weak self] in
            self?.closeWindow()
        }
        contentView.onSave = { [weak self] content in
            self?.saveContent(content)
        }
        contentView.onModeChange = { [weak self] mode, animated in
            self?.updateWindow(for: mode, animated: animated)
        }
        contentView.onInitialContentReady = { [weak self] in
            self?.presentPreparedWindow()
        }
        window?.contentView = contentView
        editContentView = contentView
    }

    func closeWindow() {
        finishModeResize()
        window?.orderOut(nil)
        currentModel = nil
        editContentView = nil
        isNewItem = false
        needsInitialPresentation = false
        window?.minSize = NSSize(width: Self.minWidth, height: Self.minHeight)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_: Notification) {
        finishModeResize()
        currentModel = nil
        editContentView = nil
        isNewItem = false
        needsInitialPresentation = false
        window?.minSize = NSSize(width: Self.minWidth, height: Self.minHeight)
    }

    func windowDidMove(_: Notification) {
        updateStableWindowCenter()
    }

    func windowDidResize(_: Notification) {
        updateStableWindowCenter()
    }

    func windowShouldZoom(_: NSWindow, toFrame _: NSRect) -> Bool {
        false
    }

    private func saveFromState() {
        guard let contentView = editContentView, contentView.isLoaded else {
            return
        }
        saveContent(contentView.currentContent)
    }

    func saveContent(_ content: EditedContent) {
        guard let model = currentModel else {
            return
        }

        let plainText: String
        let length: Int
        let actualType: PasteboardType
        let newData: Data
        let showData: Data?

        switch content {
        case let .plainText(text):
            plainText = text
            length = text.utf16.count
            actualType = .string
            newData = Data(text.utf8)
            showData = Data(text.prefix(250).utf8)
        case let .attributedText(attributedString):
            plainText = attributedString.string
            length = attributedString.length
            let isRich = Self.hasRichTextAttributes(attributedString)
            actualType = isRich ? .rtf : .string
            newData = if actualType == .string {
                Data(plainText.utf8)
            } else {
                attributedString.toData(with: actualType) ?? Data()
            }

            let showContent = length > 250
                ? attributedString.attributedSubstring(
                    from: NSRange(location: 0, length: 250)
                )
                : attributedString
            showData = showContent.toData(with: actualType)
        }

        guard !plainText.allSatisfy(\.isWhitespace) else {
            closeWindow()
            return
        }

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
                    newType: actualType,
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

    /// 在装载文本前根据模式同步设定尺寸并居中于当前屏幕。
    private func prepareInitialWindow(for mode: EditMode) {
        guard let window else { return }
        needsInitialPresentation = false
        resizeGeneration += 1
        isResizingForMode = false

        let targetWidth = mode == .json ? Self.jsonWidth : Self.minWidth
        let targetHeight = mode == .json ? Self.jsonHeight : Self.minHeight
        window.minSize = NSSize(width: targetWidth, height: targetHeight)

        let screen = window.screen ?? NSScreen.main
        var frame = window.frame
        frame.size.width = targetWidth
        frame.size.height = targetHeight
        if let visible = screen?.visibleFrame {
            frame.origin.x = visible.midX - targetWidth / 2
            frame.origin.y = visible.midY - targetHeight / 2
        }
        window.setFrame(frame, display: true)
        window.layoutIfNeeded()
        stableWindowCenter = Self.center(of: frame)
    }

    /// 文本、行号宽度和约束都稳定后再显示窗口，首帧即为文档顶部。
    private func presentPreparedWindow() {
        guard let window, !needsInitialPresentation else { return }
        window.layoutIfNeeded()
        editContentView?.scrollActiveEditorToTop()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func updateWindow(for mode: EditMode, animated: Bool) {
        guard let window else { return }

        if needsInitialPresentation {
            prepareInitialWindow(for: mode)
            return
        }

        let targetWidth = mode == .json ? Self.jsonWidth : Self.minWidth
        let targetHeight = mode == .json ? Self.jsonHeight : Self.minHeight
        let center = stableWindowCenter ?? Self.center(of: window.frame)

        resizeGeneration += 1
        let generation = resizeGeneration
        isResizingForMode = true
        window.minSize = NSSize(width: targetWidth, height: targetHeight)

        var frame = window.frame
        frame.size.width = targetWidth
        frame.size.height = targetHeight
        frame.origin.x = center.x - targetWidth / 2
        frame.origin.y = center.y - targetHeight / 2
        if let screen = window.screen {
            frame = window.constrainFrameRect(frame, to: screen)
        }

        guard window.frame != frame else {
            isResizingForMode = false
            editContentView?.scrollActiveEditorToTop()
            return
        }

        guard animated else {
            window.setFrame(frame, display: true)
            isResizingForMode = false
            stableWindowCenter = Self.center(of: window.frame)
            editContentView?.scrollActiveEditorToTop()
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.modeResizeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(frame, display: true)
        }) { [weak self] in
            Task { @MainActor in
                guard let self, generation == self.resizeGeneration else { return }
                self.isResizingForMode = false
                self.editContentView?.scrollActiveEditorToTop()
            }
        }
    }

    private func updateStableWindowCenter() {
        guard !isResizingForMode, let window else { return }
        stableWindowCenter = Self.center(of: window.frame)
    }

    private func finishModeResize() {
        resizeGeneration += 1
        isResizingForMode = false
        if let window {
            stableWindowCenter = Self.center(of: window.frame)
        }
    }

    private static func center(of frame: NSRect) -> NSPoint {
        NSPoint(x: frame.midX, y: frame.midY)
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
