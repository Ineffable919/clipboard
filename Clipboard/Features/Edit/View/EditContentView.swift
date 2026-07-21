//
//  EditContentView.swift
//  Clipboard
//
//  编辑窗口内容视图：工具栏 + 编辑器 + 统计栏
//

import AppKit
import SnapKit

final class EditContentView: NSVisualEffectView {
    // MARK: - Callbacks

    var onCancel: (() -> Void)?
    var onSave: ((EditedContent) -> Void)?
    var onModeChange: ((EditMode, Bool) -> Void)?
    var onInitialContentReady: (() -> Void)?

    /// 当前编辑内容
    var currentContent: EditedContent {
        switch mode {
        case .text:
            .attributedText(textEditor.currentContent)
        case .json:
            .plainText(jsonEditor.currentText)
        }
    }

    private(set) var isLoaded = false

    // MARK: - Subviews

    private let toolbar = EditToolbarView()
    private let textEditor = RichTextEditorView()
    private let jsonEditor = JSONEditorView()
    private let statisticsBar = EditStatisticsBar()

    private let editorCard: NSView = {
        let view = NSView()
        view.wantsLayer = true
        return view
    }()

    // MARK: - Statistics

    private var mode = EditMode.text
    private var contentTask: Task<Void, Never>?
    private var statisticsTask: Task<Void, Never>?
    private var jsonAnalysisTask: Task<Void, Never>?
    private var transformTask: Task<Void, Never>?

    // MARK: - Init

    init(model: PasteboardModel) {
        super.init(frame: .zero)
        material = .popover
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = Const.radius
        layer?.masksToBounds = true
        setup()
        loadContent(from: model)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit {
        contentTask?.cancel()
        statisticsTask?.cancel()
        jsonAnalysisTask?.cancel()
        transformTask?.cancel()
    }

    // MARK: - Setup

    private func setup() {
        addSubview(toolbar)
        addSubview(editorCard)
        editorCard.addSubview(textEditor)
        editorCard.addSubview(jsonEditor)
        addSubview(statisticsBar)

        toolbar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(36)
        }

        editorCard.snp.makeConstraints { make in
            make.top.equalTo(toolbar.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(Const.space6)
            make.bottom.equalTo(statisticsBar.snp.top)
        }

        textEditor.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        jsonEditor.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        statisticsBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(36)
        }

        toolbar.onCancel = { [weak self] in self?.onCancel?() }
        toolbar.onSave = { [weak self] in
            guard let self, isLoaded else { return }
            onSave?(currentContent)
        }
        toolbar.onFormat = { [weak self] action in
            self?.textEditor.applyFormat(action)
        }
        toolbar.onModeChange = { [weak self] mode in
            self?.requestMode(mode)
        }
        toolbar.onJSONAction = { [weak self] action in
            self?.performJSONAction(action)
        }
        toolbar.onIndentationChange = { [weak self] indentation in
            guard let self else { return }
            jsonEditor.indentation = indentation
            performJSONAction(.format(indentation))
        }

        textEditor.onTextChange = { [weak self] in
            self?.scheduleStatsUpdate()
        }
        jsonEditor.onTextChange = { [weak self] in
            self?.scheduleJSONAnalysis()
        }
        jsonEditor.onCursorChange = { [weak self] line, column in
            self?.statisticsBar.updateCursor(line: line, column: column)
        }

        jsonEditor.isHidden = true
        toolbar.setMode(.text)
        toolbar.setModeToggleVisible(false)
        statisticsBar.setMode(.text)
    }

    // MARK: - Content

    private func loadContent(from model: PasteboardModel) {
        let data = model.data
        let typeRawValue = model.pasteboardType.rawValue
        contentTask?.cancel()
        contentTask = Task { @MainActor [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                let text = EditTextLoader.load(
                    data: data,
                    typeRawValue: typeRawValue
                )
                let isJSON = JSONTransformer.looksLikeJSON(text)
                let lineStarts = isJSON ? JSONLineIndex.build(for: text) : nil
                return (text: text, isJSON: isJSON, lineStarts: lineStarts)
            }
            let loaded = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }

            guard let self, !Task.isCancelled else { return }
            let initialMode: EditMode = loaded.isJSON ? .json : .text
            isLoaded = true
            toolbar.setModeToggleVisible(loaded.isJSON)
            applyMode(
                initialMode,
                text: loaded.text,
                initialLineStarts: loaded.lineStarts
            )
        }
    }

    // MARK: - Mode

    private func requestMode(_ newMode: EditMode) {
        guard newMode != mode else { return }

        if newMode == .json, textEditor.hasRichFormatting, let window {
            Task { @MainActor [weak self, weak window] in
                guard let self, let window else { return }
                let alert = NSAlert()
                alert.messageText = String(localized: .jsonRichFormatWarningTitle)
                alert.informativeText = String(localized: .jsonRichFormatWarningMessage)
                alert.alertStyle = .warning
                alert.addButton(withTitle: String(localized: .commonConfirm))
                alert.addButton(withTitle: String(localized: .commonCancel))
                let response = await alert.beginSheetModal(for: window)
                guard response == .alertFirstButtonReturn else { return }
                applyMode(.json)
            }
            return
        }

        applyMode(newMode)
    }

    private func applyMode(
        _ newMode: EditMode,
        text initialText: String? = nil,
        initialLineStarts: [Int]? = nil
    ) {
        transformTask?.cancel()
        jsonAnalysisTask?.cancel()
        jsonEditor.isBusy = false
        toolbar.setJSONToolsEnabled(true)

        let text: String = if let initialText {
            initialText
        } else {
            switch mode {
            case .text: textEditor.currentText
            case .json: jsonEditor.currentText
            }
        }

        mode = newMode
        let isJSON = newMode == .json
        let isInitialLoad = initialText != nil
        let animated = !isInitialLoad
        if isInitialLoad {
            onModeChange?(newMode, false)
        }
        textEditor.isHidden = isJSON
        jsonEditor.isHidden = !isJSON

        if isJSON {
            textEditor.setText("")
            jsonEditor.setText(text, lineStarts: initialLineStarts)
        } else {
            jsonEditor.setText("")
            textEditor.setText(text)
        }

        toolbar.setMode(newMode)
        statisticsBar.setMode(newMode)
        if !isInitialLoad {
            onModeChange?(newMode, animated)
        }

        if isJSON {
            scheduleJSONAnalysis(immediately: true)
            jsonEditor.focus(revealingSelection: !isInitialLoad)
        } else {
            updateStats(for: text)
            textEditor.focus()
        }
        scrollActiveEditorToTop()
        if isInitialLoad {
            onInitialContentReady?()
        }
    }

    func scrollActiveEditorToTop() {
        switch mode {
        case .text: textEditor.scrollToTop()
        case .json: jsonEditor.scrollToTop()
        }
    }

    // MARK: - Statistics

    private func updateStats(for text: String) {
        statisticsTask?.cancel()
        statisticsTask = Task { @MainActor [weak self] in
            let stats = await Task.detached(priority: .utility) {
                TextStatistics(from: text)
            }.value

            guard let self, !Task.isCancelled else { return }
            statisticsBar.update(stats)
        }
    }

    private func scheduleStatsUpdate() {
        statisticsTask?.cancel()
        statisticsTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }

            let text = textEditor.currentText

            let stats = await Task.detached(priority: .utility) {
                TextStatistics(from: text)
            }.value

            guard !Task.isCancelled else { return }
            statisticsBar.update(stats)
        }
    }

    private func scheduleJSONAnalysis(immediately: Bool = false) {
        jsonAnalysisTask?.cancel()
        jsonAnalysisTask = Task { @MainActor [weak self] in
            if !immediately {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard let self, !Task.isCancelled, mode == .json else { return }
            let text = jsonEditor.currentText
            statisticsBar.setProcessing()
            let worker = Task.detached(priority: .utility) {
                let stats = TextStatistics(from: text)
                let isValid = JSONTransformer.isValid(text)
                return (stats, isValid)
            }
            let result = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }

            guard !Task.isCancelled, mode == .json else { return }
            statisticsBar.update(result.0)
            statisticsBar.setJSONValid(result.1)
        }
    }

    // MARK: - JSON Actions

    private func performJSONAction(_ action: JSONToolAction) {
        let target = jsonEditor.transformTarget()
        transformTask?.cancel()
        jsonAnalysisTask?.cancel()
        jsonEditor.isBusy = true
        statisticsBar.setProcessing()

        transformTask = Task { @MainActor [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                do {
                    return try Result<String, JSONTransformError>.success(
                        JSONTransformer.transform(target.text, action: action)
                    )
                } catch let error as JSONTransformError {
                    return .failure(error)
                } catch {
                    return .failure(.invalidJSON)
                }
            }
            let result = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }

            guard let self, !Task.isCancelled else { return }
            jsonEditor.isBusy = false

            switch result {
            case let .success(text):
                let changed = jsonEditor.replaceText(text, in: target.range)
                if !changed {
                    scheduleJSONAnalysis(immediately: true)
                }
            case let .failure(error):
                switch error {
                case let .duplicateKey(key):
                    statisticsBar.setError(String(localized: .jsonDuplicateKey(key)))
                case .invalidJSON:
                    statisticsBar.setError(String(localized: .jsonTransformFailed))
                case .cancelled:
                    scheduleJSONAnalysis(immediately: true)
                }
            }
        }
    }

    // MARK: - Appearance

    override func updateLayer() {
        super.updateLayer()

        // 中间编辑卡片
        editorCard.layer?.cornerRadius = 6.0
        editorCard.layer?.masksToBounds = true
        editorCard.layer?.borderWidth = 1
        editorCard.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        editorCard.layer?.borderColor = NSColor.separatorColor.cgColor
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
