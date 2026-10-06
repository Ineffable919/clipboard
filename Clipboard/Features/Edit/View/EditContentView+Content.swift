import AppKit

extension EditContentView {
    // MARK: - Content

    func loadContent(from model: PasteboardModel) {
        let data = model.data
        let typeRawValue = model.pasteboardType.rawValue
        let width = jsonEditor.preparationWidth
        contentTask?.cancel()
        contentTask = Task { @MainActor [weak self] in
            let worker = Task.detached(priority: .userInitiated) { [weak self] in
                await JSONDocument.load(data: data, type: typeRawValue, width: width) { [weak self] isValid in
                    guard let self, !isClosed, !Task.isCancelled else { return }
                    toolbar.setMode(isValid ? .json : .text)
                    onModeChange?(isValid ? .json : .text)
                }
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
                preparedText: loaded.preparedText,
                knownValidity: loaded.isValid
            )
        }
    }

    // MARK: - Mode

    func applyMode(
        _ newMode: EditMode,
        text initialText: String? = nil,
        initialDocument: JSONFoldIndex.Document? = nil,
        preparedText: JSONPreparedText? = nil,
        knownValidity: Bool? = nil
    ) {
        transformTask?.cancel()
        jsonAnalysisTask?.cancel()
        jsonEditor.isBusy = false

        let needsReload = newMode == .json ? needsJSONReload : needsTextReload
        let text: String = if let initialText {
            initialText
        } else if !needsReload, statistics != nil || statisticsTask != nil {
            ""
        } else {
            switch mode {
            case .text: textEditor.currentText
            case .json: jsonEditor.currentText
            }
        }

        // 两种编辑器共用窗口撤销栈，切换时保留原有清空行为，避免撤销修改隐藏的编辑器
        if newMode != mode { window?.undoManager?.removeAllActions() }
        // 最终尺寸和新模式在同一次刷新中显示，避免旧尺寸下先出现新内容
        window?.disableScreenUpdatesUntilFlush()
        textEditor.isHidden = true
        jsonEditor.isHidden = true
        mode = newMode
        let isJSON = newMode == .json
        let isInitialLoad = initialText != nil
        toolbar.setMode(newMode)
        statisticsBar.setMode(newMode)
        onModeChange?(newMode)
        layoutSubtreeIfNeeded()
        updateEditor(text, document: initialDocument, preparedText: preparedText)
        textEditor.isHidden = isJSON
        jsonEditor.isHidden = !isJSON

        updateModeStatistics(text, validity: knownValidity, document: initialDocument, initialText: initialText)
        if isJSON {
            jsonEditor.focus(revealingSelection: !isInitialLoad)
        } else {
            textEditor.focus()
        }
        scrollActiveEditorToTop()
        toolbar.refreshHover()
    }

    func scrollActiveEditorToTop() {
        switch mode {
        case .text: textEditor.scrollToTop()
        case .json: jsonEditor.scrollToTop()
        }
    }

    // MARK: - Statistics

    func updateStats(for text: String, lineCount: Int? = nil) {
        statisticsTask?.cancel()
        statisticsTask = Task { @MainActor [weak self] in
            let worker = Task.detached(priority: .utility) {
                await TextStatisticsWorker.shared.count(text, lineCount: lineCount)
            }
            let stats = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }

            guard let self, let stats, !Task.isCancelled else { return }
            statistics = stats
            statisticsTask = nil
            statisticsBar.update(stats)
        }
    }

    func scheduleStatsUpdate() {
        statisticsTask?.cancel()
        statisticsTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let text = self?.textEditor.currentText else { return }
            self?.statisticsTask = nil
            self?.updateStats(for: text)
        }
    }

    func requestMode(_ newMode: EditMode) {
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
                switchMode(.json)
            }
            return
        }

        switchMode(newMode)
    }

    func updateEditor(_ text: String, document: JSONFoldIndex.Document?, preparedText: JSONPreparedText?) {
        if mode == .json {
            if needsJSONReload {
                jsonEditor.indentation = JSONIndentation.detect(in: text)
                jsonEditor.setText(text, document: document, preparedText: preparedText)
                needsJSONReload = false
                needsTextReload = true
            }
            toolbar.setIndentation(jsonEditor.indentation)
        } else if needsTextReload {
            textEditor.setText(text, prepared: preparedText ?? jsonEditor.preparedContent)
            needsTextReload = false
        }
    }

    func updateModeStatistics(
        _ text: String, validity: Bool?, document: JSONFoldIndex.Document?, initialText: String?
    ) {
        if mode == .json {
            if let statistics, let validity = validity ?? jsonEditor.knownValidity {
                jsonEditor.knownValidity = validity
                statisticsBar.update(statistics)
                statisticsBar.setJSONValid(validity)
            } else {
                scheduleJSONAnalysis(
                    immediately: true, knownValidity: validity ?? jsonEditor.knownValidity,
                    knownLineCount: document?.statisticsLineCount, initialText: initialText
                )
            }
        } else if let statistics {
            statisticsBar.update(statistics)
        } else if statisticsTask == nil {
            updateStats(for: text)
        }
    }

    func switchMode(_ newMode: EditMode) {
        guard newMode == .json, needsJSONReload else {
            applyMode(newMode)
            return
        }
        let text = textEditor.currentText
        guard text.utf8.count >= 1_048_576 else {
            applyMode(newMode)
            return
        }
        // 修改后的大文本一次性准备校验和索引，避免同时启动多个全文扫描
        contentTask?.cancel()
        statisticsTask?.cancel()
        statisticsTask = nil
        isLoaded = false
        textEditor.isEditable = false
        toolbar.setLoading(true)
        setLoading(true)
        let width = jsonEditor.preparationWidth
        let validity = jsonEditor.knownValidity
        contentTask = Task { @MainActor [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                JSONDocument.prepare(text, knownValidity: validity, width: width)
            }
            let document = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
            guard let self, !Task.isCancelled, !isClosed else { return }
            isLoaded = true
            textEditor.isEditable = true
            toolbar.setLoading(false)
            applyMode(
                newMode, text: document.text, initialDocument: document.index,
                preparedText: document.preparedText, knownValidity: document.isValid
            )
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
            if statistics != nil || statisticsTask != nil { return }
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
            guard let self, !Task.isCancelled, mode == .json else { return }
            if let statistics {
                statisticsBar.update(statistics)
            } else if statisticsTask == nil {
                updateStats(for: text, lineCount: knownLineCount)
            }
        }
    }

}
