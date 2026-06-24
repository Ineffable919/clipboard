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
    var onSave: ((NSAttributedString) -> Void)?

    /// 当前编辑内容
    var currentContent: NSAttributedString {
        editor.currentContent
    }

    // MARK: - Subviews

    private let toolbar = EditToolbarView()
    private let editor = RichTextEditorView()
    private let statisticsBar = EditStatisticsBar()

    private let editorCard: NSView = {
        let view = NSView()
        view.wantsLayer = true
        return view
    }()

    // MARK: - Statistics

    private var statisticsTask: Task<Void, Never>?
    private var lastStatisticsText = ""

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

    // MARK: - Setup

    private func setup() {
        addSubview(toolbar)
        addSubview(editorCard)
        editorCard.addSubview(editor)
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

        editor.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        statisticsBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(36)
        }

        toolbar.onCancel = { [weak self] in self?.onCancel?() }
        toolbar.onSave = { [weak self] in
            guard let self else { return }
            onSave?(currentContent)
        }
        toolbar.onFormat = { [weak self] action in
            self?.editor.applyFormat(action)
        }

        editor.onTextChange = { [weak self] in
            self?.scheduleStatisticsUpdate()
        }
    }

    // MARK: - Content

    private func loadContent(from model: PasteboardModel) {
        let attributedString: NSAttributedString = if let attr = NSAttributedString(
            with: model.data,
            type: model.pasteboardType
        ) {
            attr
        } else {
            NSAttributedString(
                string: String(data: model.data, encoding: .utf8) ?? ""
            )
        }

        editor.setContent(attributedString)

        let text = attributedString.string
        lastStatisticsText = text
        statisticsBar.update(TextStatistics(from: text))
    }

    // MARK: - Statistics

    private func scheduleStatisticsUpdate() {
        let currentText = currentContent.string
        guard currentText != lastStatisticsText else { return }

        statisticsTask?.cancel()
        statisticsTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            let text = currentText
            let stats = await Task.detached(priority: .utility) {
                await TextStatistics(from: text)
            }.value

            guard !Task.isCancelled else { return }
            lastStatisticsText = text
            statisticsBar.update(stats)
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
