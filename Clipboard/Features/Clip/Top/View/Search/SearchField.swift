//
//  SearchField.swift
//  Clipboard
//
//  Created by crown on 2026/4/9
//

import AppKit
import Combine
import SnapKit

/// 输入框的一次完整查询；光标和输入法组合文本仍由 NSTextView 管理
struct SearchInputQuery: Equatable {
    var text = ""
    var tags: [InputTag] = []

    var isEmpty: Bool { text.isEmpty && tags.isEmpty }
}

final class SearchField: NSView {
    @Published private(set) var query = SearchInputQuery()
    var text: String { query.text }
    private var pendingTags: [InputTag]?

    var onResignFirstResponder: (() -> Void)?
    var onBecomeFirstResponder: (() -> Void)?
    var onQueryChanged: ((SearchInputQuery) -> Void)?
    var onFilterButtonTapped: (() -> Void)?
    var suggestionsTask: Task<Void, Never>?
    var onSuggestionsNeeded: ((String) async throws -> [SearchSuggestionItem])?
    var onSuggestionSelected: ((SearchSuggestionItem) -> Void)?

    var stringValue: String {
        get { tokenTextView.getPlainText() }
        set {
            if newValue.isEmpty {
                clearAllContent()
            } else {
                tokenTextView.string = newValue
                synchronizeQuery()
            }
        }
    }

    var placeholderString: String? {
        didSet { tokenTextView.placeholderString = placeholderString ?? "" }
    }

    var isFirstResponder: Bool { window?.firstResponder === tokenTextView }

    override func becomeFirstResponder() -> Bool {
        window?.makeFirstResponder(tokenTextView)
        return true
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = if #available(macOS 26.0, *) { bounds.height / 2 } else { 6 }
        syncTextViewFrameToScrollView()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            hideSuggestions()
        }
    }

    // MARK: - Subviews

    private let searchIcon = NSImageView()
    private let scrollView = HorizontalScrollView()
    let tokenTextView = TokenTextView.makeConfigured()
    private let cancelButton = NSButton()
    let filterButton = FilterIconButton()

    // MARK: - Suggestion Window

    lazy var suggestionWindow = SearchSuggestionWindow()

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false
        updateColors()

        setupSearchIcon()
        setupFilterButton()
        setupCancelButton()
        setupTokenTextView()
        setupSuggestionKeyHandling()
    }

    private func setupSearchIcon() {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        searchIcon.image = NSImage(
            systemSymbolName: "magnifyingglass",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(config)
        searchIcon.contentTintColor = .secondaryLabelColor
        addSubview(searchIcon)

        searchIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Const.space8)
            make.centerY.equalToSuperview()
        }
    }

    private func setupCancelButton() {
        cancelButton.bezelStyle = .inline
        cancelButton.isBordered = false
        cancelButton.refusesFirstResponder = true
        cancelButton.image = NSImage(
            systemSymbolName: "xmark.circle.fill",
            accessibilityDescription: nil
        )
        cancelButton.contentTintColor = .secondaryLabelColor
        cancelButton.target = self
        cancelButton.action = #selector(clear)
        cancelButton.isHidden = true
        addSubview(cancelButton)

        cancelButton.snp.makeConstraints { make in
            make.trailing.equalTo(filterButton.snp.leading).offset(-Const.space4)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }
    }

    private func setupFilterButton() {
        filterButton.onTap = { [weak self] in
            self?.onFilterButtonTapped?()
        }
        addSubview(filterButton)

        filterButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Const.space8)
            make.centerY.equalToSuperview()
        }
    }

    private func setupTokenTextView() {
        tokenTextView.delegate = self

        tokenTextView.onTextChanged = { [weak self] _ in
            self?.synchronizeQuery()
        }
        tokenTextView.onBecomeFirstResponder = { [weak self] in self?.onBecomeFirstResponder?() }
        tokenTextView.onResignFirstResponder = { [weak self] in
            self?.hideSuggestions()
            self?.onResignFirstResponder?()
        }

        scrollView.focusRingMaskView = self

        scrollView.documentView = tokenTextView
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none

        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        addSubview(scrollView)

        scrollView.snp.makeConstraints { make in
            make.leading.equalTo(searchIcon.snp.trailing).offset(Const.space4)
            make.trailing.equalTo(cancelButton.snp.leading).offset(-Const.space4)
            make.centerY.equalToSuperview()
            make.height.equalTo(TokenAttachment.lineHeight)
        }

        syncTextViewFrameToScrollView()
    }

    // MARK: - Appearance

    override func updateLayer() {
        super.updateLayer()
        updateColors()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        if #available(macOS 26.0, *) {
            let color = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.15)
                : NSColor(white: 0.0, alpha: 0.1)
            layer?.backgroundColor = color.cgColor
        } else {
            let color = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.12)
                : NSColor(white: 0.0, alpha: 0.1)
            layer?.backgroundColor = color.cgColor
        }
    }

    // MARK: - Actions

    func moveCursorToEnd() {
        let length = tokenTextView.textStorage?.length ?? 0
        tokenTextView.setSelectedRange(NSRange(location: length, length: 0))
        tokenTextView.scrollRangeToVisible(tokenTextView.selectedRange())
    }

    @objc func clear() {
        clearAllContent()
        if !isFirstResponder {
            window?.makeFirstResponder(tokenTextView)
            onBecomeFirstResponder?()
        }
    }

    func clearAllContent() {
        hideSuggestions()
        pendingTags = nil
        tokenTextView.string = ""
        tokenTextView.setSelectedRange(NSRange(location: 0, length: 0))
        tokenTextView.restorePlainTextInputState()
        synchronizeQuery()
    }

    func clearTextSilently() {
        hideSuggestions()
        if tokenTextView.hasMarkedText() { tokenTextView.unmarkText() }
        let length = tokenTextView.textStorage?.length ?? 0
        let start = min(tokenTextView.findTokenEndIndex(), length)
        tokenTextView.textStorage?.deleteCharacters(in: NSRange(location: start, length: length - start))
        tokenTextView.moveCursorToEnd()
        synchronizeQuery(notify: false)
    }

    func setTokens(_ tags: [InputTag]) {
        pendingTags = tags
        guard !tokenTextView.hasMarkedText() else {
            hideSuggestions()
            return
        }
        pendingTags = nil
        tokenTextView.replaceTokens(tags)
        if !synchronizeQuery(notify: false) { updateSuggestions() }
    }

    @discardableResult
    private func synchronizeQuery(notify: Bool = true) -> Bool {
        if let pendingTags, !tokenTextView.hasMarkedText() {
            self.pendingTags = nil
            tokenTextView.replaceTokens(pendingTags)
        }
        let updated = SearchInputQuery(
            text: tokenTextView.getPlainText(),
            tags: pendingTags ?? tokenTextView.getAllTokens()
        )
        let changed = updated != query
        if changed {
            query = updated
            if notify { onQueryChanged?(updated) }
        }
        cancelButton.isHidden = updated.isEmpty
        if changed { updateSuggestions() }
        return changed
    }

    private func syncTextViewFrameToScrollView() {
        let bounds = scrollView.contentView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        tokenTextView.frame = bounds
    }

    func appendText(_ character: String) {
        guard !character.isEmpty else { return }
        tokenTextView.insertText(character, replacementRange: NSRange(location: NSNotFound, length: 0))
        moveCursorToEnd()
    }

}

// MARK: - NSTextViewDelegate

extension SearchField: NSTextViewDelegate {
    func textDidChange(_: Notification) {
        synchronizeQuery()
    }

    func textDidBeginEditing(_: Notification) {
        onBecomeFirstResponder?()
    }
}

extension SearchField {
    var modeIconView: NSImageView { searchIcon }
    var modeTrailingViews: [NSView] { [cancelButton, filterButton] }

    func setFocusRingSuppressed(_ suppressed: Bool) {
        scrollView.isFocusRingSuppressed = suppressed
    }

    func refreshFocusRingMask() {
        scrollView.noteFocusRingMaskChanged()
    }
}
