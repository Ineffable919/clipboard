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
    var onModeChange: ((EditMode) -> Void)?

    /// 当前编辑内容
    var currentContent: EditedContent {
        switch mode {
        case .text:
            .attributedText(textEditor.currentContent)
        case .json:
            .plainText(jsonEditor.currentText)
        }
    }

    var isLoaded = false

    // MARK: - Subviews

    let toolbar = EditToolbarView()
    let textEditor = RichTextEditorView()
    let jsonEditor = JSONEditorView()
    let statisticsBar = EditStatisticsBar()
    let loadingView = NSView()
    let loadingIndicator = NSProgressIndicator()

    let editorCard: NSView = {
        let view = NSView()
        view.wantsLayer = true
        return view
    }()

    // MARK: - Statistics

    var mode = EditMode.text
    var contentTask: Task<Void, Never>?
    var statisticsTask: Task<Void, Never>?
    var jsonAnalysisTask: Task<Void, Never>?
    var transformTask: Task<Void, Never>?
    var statistics: TextStatistics?
    var needsTextReload = true
    var needsJSONReload = true
    var isClosed = false

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

    func cancelWork() {
        isClosed = true
        contentTask?.cancel()
        statisticsTask?.cancel()
        jsonAnalysisTask?.cancel()
        transformTask?.cancel()
        jsonEditor.cancelWork()
        textEditor.cancelWork()
        setLoading(false)
    }

    // MARK: - Setup

    func setup() {
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

        setupCallbacks()

        jsonEditor.isHidden = true
        textEditor.isHidden = true
        toolbar.setMode(mode)
        toolbar.setLoading(true)
        toolbar.setModeToggleVisible(false)
        statisticsBar.setMode(mode)
        statisticsBar.isHidden = true
    }

    private func setupCallbacks() {
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
            self?.needsJSONReload = true
            self?.jsonEditor.knownValidity = nil
            self?.statistics = nil
            self?.scheduleStatsUpdate()
        }
        jsonEditor.onTextChange = { [weak self] lineCount in
            guard let self else { return }
            needsTextReload = true
            statistics = nil
            statisticsTask?.cancel()
            statisticsTask = nil
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

extension EditContentView {
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

}
