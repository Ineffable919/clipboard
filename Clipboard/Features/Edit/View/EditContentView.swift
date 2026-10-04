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
    private let loadingView = NSView()
    private let loadingIndicator = NSProgressIndicator()

    let initialMode: EditMode

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
    private var jsonStatistics: TextStatistics?
    private var isClosed = false

    // MARK: - Init

    init(model: PasteboardModel) {
        let prefix = String(bytes: model.data.prefix(4096), encoding: .utf8) ?? ""
        initialMode = JSONTransformer.looksLikeJSON(prefix) ? .json : .text
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

    func cancelWork() {
        isClosed = true
        contentTask?.cancel()
        statisticsTask?.cancel()
        jsonAnalysisTask?.cancel()
        transformTask?.cancel()
        jsonEditor.cancelWork()
        setLoading(false)
    }

    // MARK: - Setup

    private func setup() {
        addSubview(toolbar)
        addSubview(editorCard)
        editorCard.addSubview(textEditor)
        editorCard.addSubview(jsonEditor)
        editorCard.addSubview(loadingView)
        loadingView.addSubview(loadingIndicator)
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

        setupLoading()

        statisticsBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(36)
        }

        toolbar.onCancel = { [weak self] in self?.onCancel?() }
        toolbar.onSave = { [weak self] in
            guard let self, isLoaded, !jsonEditor.isBusy else { return }
            onSave?(currentContent)
        }
        toolbar.onFormat = { [weak self] action in
            guard self?.isLoaded == true else { return }
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
        jsonEditor.onTextChange = { [weak self] lineCount in
            guard let self else { return }
            jsonStatistics = nil
            scheduleJSONAnalysis(
                immediately: jsonEditor.knownValidity != nil,
                knownValidity: jsonEditor.knownValidity, knownLineCount: lineCount
            )
        }
        jsonEditor.onBusyChange = { [weak self] busy in
            guard let self else { return }
            if busy {
                transformTask?.cancel()
                jsonAnalysisTask?.cancel()
            }
            toolbar.setJSONToolsEnabled(!busy)
            setLoading(busy)
        }
        jsonEditor.onCursorChange = { [weak self] line, column in
            self?.statisticsBar.updateCursor(line: line, column: column)
        }

        jsonEditor.isHidden = true
        textEditor.isHidden = true
        toolbar.setMode(initialMode)
        toolbar.setLoading(true)
        toolbar.setModeToggleVisible(false)
        statisticsBar.setMode(initialMode)
        statisticsBar.isHidden = true
    }

    // MARK: - Content

    private func loadContent(from model: PasteboardModel) {
        let data = model.data
        let typeRawValue = model.pasteboardType.rawValue
        let width = jsonEditor.preparationWidth
        contentTask?.cancel()
        contentTask = Task { @MainActor [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                JSONDocument.load(data: data, type: typeRawValue, width: width)
            }
            let loaded = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }

            guard let self, !Task.isCancelled else { return }
            let initialMode: EditMode = loaded.isValid ? .json : .text
            isLoaded = true
            toolbar.setLoading(false)
            setLoading(false)
            statisticsBar.isHidden = false
            toolbar.setModeToggleVisible(loaded.isValid)
            applyMode(
                initialMode,
                text: loaded.text,
                initialDocument: loaded.index,
                preparedText: loaded.preparedText
            )
        }
    }

    // MARK: - Mode

    private func requestMode(_ newMode: EditMode) {
        guard isLoaded else { return }
        guard newMode != mode else { return }

        if newMode == .json, textEditor.hasRichFormatting, let window {
            Task { @MainActor [weak self, weak window] in
                guard let self, let window else { return }
                let alert = NSAlert.appAlert()
                alert.messageText = String(localized: .jsonRichWarningTitle)
                alert.informativeText = String(localized: .jsonRichWarningMessage)
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
        initialDocument: JSONFoldIndex.Document? = nil,
        preparedText: JSONPreparedText? = nil
    ) {
        transformTask?.cancel()
        jsonAnalysisTask?.cancel()
        jsonStatistics = nil
        jsonEditor.isBusy = false

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
            jsonEditor.indentation = JSONIndentation.detect(in: text)
            toolbar.setIndentation(jsonEditor.indentation)
            textEditor.setText("")
            jsonEditor.setText(text, document: initialDocument, preparedText: preparedText)
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
            scheduleJSONAnalysis(
                immediately: true,
                knownValidity: isInitialLoad ? true : nil,
                knownLineCount: initialDocument?.statisticsLineCount,
                initialText: initialText
            )
            jsonEditor.focus(revealingSelection: !isInitialLoad)
        } else {
            updateStats(for: text)
            textEditor.focus()
        }
        scrollActiveEditorToTop()
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
            let worker = Task.detached(priority: .utility) {
                TextStatistics(from: text)
            }
            let stats = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }

            guard let self, !Task.isCancelled else { return }
            statisticsBar.update(stats)
        }
    }

    private func scheduleStatsUpdate() {
        statisticsTask?.cancel()
        statisticsTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let text = self?.textEditor.currentText else { return }
            self?.updateStats(for: text)
        }
    }

    // MARK: - JSON Actions

    private func setLoading(_ loading: Bool) {
        loadingView.isHidden = !loading
        if loading {
            loadingIndicator.startAnimation(nil)
        } else {
            loadingIndicator.stopAnimation(nil)
        }
    }

    private func performJSONAction(_ action: JSONToolAction) {
        guard isLoaded, !jsonEditor.isBusy else { return }
        let target = jsonEditor.transformTarget()
        let replacesDocument = target.range.location == 0
            && target.range.length == (jsonEditor.currentText as NSString).length
        let width = jsonEditor.preparationWidth
        let knownValidity = replacesDocument ? jsonEditor.knownValidity : nil
        transformTask?.cancel()
        jsonAnalysisTask?.cancel()
        jsonEditor.isBusy = true

        transformTask = Task { @MainActor [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                do {
                    return try Result<(JSONDocument, Bool), JSONTransformError>.success(
                        JSONDocument.transform(
                            target.text, action: action, entireDocument: replacesDocument,
                            knownValidity: knownValidity, width: width
                        )
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
            defer { jsonEditor.isBusy = false }

            switch result {
            case let .success((document, hasChanges)):
                let changed = hasChanges && jsonEditor.replaceText(
                    document.text, in: target.range, document: document.index,
                    previousText: target.text, preparedText: document.preparedText,
                    knownValidity: document.isValid
                )
                if !changed, jsonStatistics == nil {
                    scheduleJSONAnalysis(
                        immediately: true, knownValidity: replacesDocument ? document.isValid : jsonEditor.knownValidity
                    )
                }
                if !changed, let validity = jsonEditor.knownValidity {
                    statisticsBar.setJSONValid(validity)
                }
                jsonEditor.scrollToTop()
            case let .failure(error): showJSONError(error)
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
        loadingView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

private extension EditContentView {
    func setupLoading() {
        loadingView.wantsLayer = true
        loadingView.layer?.cornerRadius = 8
        loadingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(48)
        }
        loadingIndicator.style = .spinning
        loadingIndicator.controlSize = .regular
        loadingIndicator.isDisplayedWhenStopped = false
        loadingIndicator.startAnimation(nil)
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(24)
        }
    }

    func scheduleJSONAnalysis(
        immediately: Bool = false,
        knownValidity: Bool? = nil,
        knownLineCount: Int? = nil,
        initialText: String? = nil
    ) {
        guard !isClosed else { return }
        jsonAnalysisTask?.cancel()
        jsonEditor.knownValidity = knownValidity
        if let knownValidity {
            statisticsBar.setJSONValid(knownValidity)
        } else {
            statisticsBar.setProcessing()
        }
        jsonAnalysisTask = Task { @MainActor [weak self] in
            if !immediately {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard !Task.isCancelled, self?.mode == .json,
                  let text = initialText ?? self?.jsonEditor.currentText else { return }
            if knownValidity == nil {
                let validator = Task.detached(priority: .utility) {
                    JSONTransformer.isValid(text)
                }
                let isValid = await withTaskCancellationHandler {
                    await validator.value
                } onCancel: {
                    validator.cancel()
                }
                guard !Task.isCancelled else { return }
                self?.jsonEditor.knownValidity = isValid
                self?.statisticsBar.setJSONValid(isValid)
            }
            let worker = Task.detached(priority: .utility) {
                TextStatistics(from: text, lineCount: knownLineCount)
            }
            let result = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }

            guard let self, !Task.isCancelled, mode == .json else { return }
            jsonStatistics = result
            statisticsBar.update(result)
        }
    }

    func showJSONError(_ error: JSONTransformError) {
        switch error {
        case let .duplicateKey(key):
            statisticsBar.setError(String(localized: .jsonDuplicateKey(key)))
        case .invalidJSON:
            statisticsBar.setError(String(localized: .jsonTransformFailed))
        case .cancelled:
            scheduleJSONAnalysis(immediately: true, knownValidity: jsonEditor.knownValidity)
        }
    }
}
