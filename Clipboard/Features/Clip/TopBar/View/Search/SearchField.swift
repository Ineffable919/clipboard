//
//  SearchField.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit
import Combine
import SnapKit

final class SearchField: NSView {
    @Published private(set) var text: String = ""

    var onResignFirstResponder: (() -> Void)?
    var onBecomeFirstResponder: (() -> Void)?
    var onTextChanged: ((String) -> Void)?
    var onFilterButtonTapped: (() -> Void)?
    var onTokenDeleted: ((InputTag) -> Void)?
    var onClearAllFilters: (() -> Void)?

    var onSuggestionsNeeded: ((String) -> [SearchSuggestionItem])?
    var onSuggestionSelected: ((SearchSuggestionItem) -> Void)?

    var stringValue: String {
        get { tokenTextView.getPlainText() }
        set {
            if newValue.isEmpty {
                clearAllContent()
            } else {
                tokenTextView.string = newValue
                updateCancelButtonVisibility()
            }
        }
    }

    var placeholderString: String? {
        didSet { tokenTextView.placeholderString = placeholderString ?? "" }
    }

    var isFirstResponder: Bool {
        window?.firstResponder === tokenTextView
    }

    override func becomeFirstResponder() -> Bool {
        window?.makeFirstResponder(tokenTextView)
        return true
    }

    override func layout() {
        super.layout()
        syncTextViewFrameToScrollView()
        updateFocusRingLayout()
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
    private let tokenTextView = TokenTextView.makeConfigured()
    private let cancelButton = NSButton()
    let filterButton = FilterIconButton()

    private var showsFocusRing = false

    // MARK: - Suggestion Window

    lazy var suggestionWindow = SearchSuggestionWindow()

    private lazy var focusRingLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = nil
        layer.lineWidth = 3.5
        layer.opacity = 0
        return layer
    }()

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
        layer?.cornerRadius = Const.topRadius
        layer?.masksToBounds = false
        updateColors()

        setupSearchIcon()
        setupFilterButton()
        setupCancelButton()
        setupTokenTextView()
        setupFocusRing()
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
            make.trailing.equalTo(filterButton.snp.leading).offset(-Const.space2)
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
            make.trailing.equalToSuperview().offset(-Const.space6)
            make.centerY.equalToSuperview()
        }
    }

    private func setupTokenTextView() {
        tokenTextView.delegate = self

        tokenTextView.onTokenDeleted = { [weak self] tag in
            self?.handleTokenDeleted(tag)
        }
        tokenTextView.onTextChanged = { [weak self] plainText in
            self?.handleTextChanged(plainText)
        }
        tokenTextView.onBecomeFirstResponder = { [weak self] in
            self?.showFocusRing()
            self?.onBecomeFirstResponder?()
        }
        tokenTextView.onResignFirstResponder = { [weak self] in
            self?.hideFocusRing()
            self?.hideSuggestions()
            self?.onResignFirstResponder?()
        }

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
            make.leading.equalTo(searchIcon.snp.trailing)
            make.trailing.equalTo(cancelButton.snp.leading).offset(-Const.space4)
            make.centerY.equalToSuperview()
            make.height.equalTo(28)
        }

        syncTextViewFrameToScrollView()
    }

    // MARK: - Focus Ring

    private static let focusRingOutset: CGFloat = 0.5

    private func setupFocusRing() {
        guard let hostLayer = layer else { return }
        focusRingLayer.strokeColor = NSColor.keyboardFocusIndicatorColor.cgColor
        hostLayer.addSublayer(focusRingLayer)
        updateFocusRingLayout()
    }

    private func updateFocusRingLayout() {
        let outset = Self.focusRingOutset
        focusRingLayer.frame = bounds.insetBy(dx: -outset, dy: -outset)
        let pathRect = CGRect(origin: .zero, size: focusRingLayer.frame.size)
        let cornerRadius = Const.topRadius + outset
        focusRingLayer.path = CGPath(
            roundedRect: pathRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
    }

    private func showFocusRing() {
        guard !showsFocusRing else { return }
        showsFocusRing = true
        updateFocusRingLayout()

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        focusRingLayer.opacity = 1.0
        CATransaction.commit()
    }

    private func hideFocusRing() {
        guard showsFocusRing else { return }
        showsFocusRing = false

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        focusRingLayer.opacity = 0
        CATransaction.commit()
    }

    // MARK: - Appearance

    override func updateLayer() {
        super.updateLayer()
        updateColors()
        focusRingLayer.strokeColor = NSColor.keyboardFocusIndicatorColor.cgColor
    }

    private func updateColors() {
        if #available(macOS 26.0, *) {
            let color = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor.unemphasizedSelectedContentBackgroundColor
                : NSColor.secondaryLabelColor.withAlphaComponent(0.1)
            layer?.backgroundColor = color.cgColor
        } else {
            let color = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
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
        let hadTokens = !tokenTextView.getAllTokens().isEmpty
        tokenTextView.clearAllTokens()
        tokenTextView.string = ""
        text = ""
        cancelButton.isHidden = true
        hideSuggestions()
        onTextChanged?("")
        if hadTokens {
            onClearAllFilters?()
        }
    }

    func clearTextSilently() {
        tokenTextView.string = ""
        text = ""
        updateCancelButtonVisibility()
    }

    func clearTokensOnly() {
        tokenTextView.clearAllTokens()
        updateCancelButtonVisibility()
    }

    func insertToken(_ tag: InputTag) {
        tokenTextView.insertToken(tag)
        updateCancelButtonVisibility()
    }

    func insertTokens(_ tags: [InputTag]) {
        guard !tags.isEmpty else { return }
        tokenTextView.insertTokens(tags)
        updateCancelButtonVisibility()
    }

    func removeToken(_ tag: InputTag) {
        tokenTextView.removeToken(tag)
        updateCancelButtonVisibility()
    }

    func getAllTokens() -> [InputTag] {
        tokenTextView.getAllTokens()
    }

    private func handleTokenDeleted(_ tag: InputTag) {
        onTokenDeleted?(tag)
        updateCancelButtonVisibility()
    }

    private func handleTextChanged(_ plainText: String) {
        text = plainText
        onTextChanged?(plainText)
        updateCancelButtonVisibility()
        updateSuggestions()
    }

    private func updateCancelButtonVisibility() {
        let hasContent = !text.isEmpty || !tokenTextView.getAllTokens().isEmpty
        cancelButton.isHidden = !hasContent
    }

    private func syncTextViewFrameToScrollView() {
        let bounds = scrollView.contentView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        tokenTextView.frame = bounds
    }

    func notifyTextChanged(_ value: String) {
        text = value
        cancelButton.isHidden = value.isEmpty && tokenTextView.getAllTokens().isEmpty
        onTextChanged?(value)
    }

    func appendText(_ character: String) {
        guard !character.isEmpty else { return }
        tokenTextView.insertText(
            character,
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        let plainText = tokenTextView.getPlainText()
        text = plainText
        updateCancelButtonVisibility()
        onTextChanged?(plainText)
        moveCursorToEnd()
        Task { @MainActor [weak self] in
            self?.updateSuggestions()
        }
    }

    // MARK: - Suggestion Window

    private func setupSuggestionKeyHandling() {
        tokenTextView.onKeyDown = { [weak self] event in
            self?.handleSuggestionKeyEvent(event) ?? false
        }

        suggestionWindow.suggestionVC.onSelectItem = { [weak self] item in
            self?.handleSuggestionItemSelected(item)
        }
    }

    private func handleSuggestionKeyEvent(_ event: NSEvent) -> Bool {
        guard suggestionWindow.isVisible else { return false }

        switch event.keyCode {
        case 125: // ↓
            return suggestionWindow.suggestionVC.selectNext()
        case 126: // ↑
            return suggestionWindow.suggestionVC.selectPrevious()
        case 36: // Enter
            return suggestionWindow.suggestionVC.applySelection()
        case 53: // Esc
            hideSuggestions()
            return true
        default:
            return false
        }
    }

    func showSuggestions() {
        updateSuggestions()
    }

    func hideSuggestions() {
        guard suggestionWindow.isVisible else { return }
        suggestionWindow.hide()
    }

    private func updateSuggestions() {
        let query = text
        guard !query.isEmpty else {
            hideSuggestions()
            return
        }

        let items = onSuggestionsNeeded?(query) ?? []
        guard !items.isEmpty else {
            hideSuggestions()
            return
        }

        suggestionWindow.suggestionVC.reloadData(items, query: query)

        let cursorScreenOrigin = cursorScreenPosition()

        if !suggestionWindow.isVisible {
            guard let win = tokenTextView.window ?? window else { return }
            suggestionWindow.show(at: cursorScreenOrigin, items: items, query: query, parentWindow: win)
        } else {
            suggestionWindow.updateFrame(at: cursorScreenOrigin, items: items, query: query)
        }
    }

    private func cursorScreenPosition() -> NSPoint {
        guard let lm = tokenTextView.layoutManager,
              let tc = tokenTextView.textContainer
        else {
            let fieldBounds = convert(bounds, to: nil)
            let screenFrame = window?.convertToScreen(fieldBounds) ?? .zero
            return NSPoint(x: screenFrame.origin.x, y: screenFrame.origin.y)
        }

        let insertionPoint = tokenTextView.selectedRange().location
        let glyphRange = lm.glyphRange(
            forCharacterRange: NSRange(location: insertionPoint, length: 0),
            actualCharacterRange: nil
        )
        let caretRect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)

        let inset = tokenTextView.textContainerInset
        let localPoint = NSPoint(
            x: caretRect.origin.x + inset.width,
            y: caretRect.maxY + inset.height
        )

        let windowPoint = tokenTextView.convert(localPoint, to: nil)
        return tokenTextView.window?.convertToScreen(
            NSRect(origin: windowPoint, size: .zero)
        ).origin ?? windowPoint
    }

    private func handleSuggestionItemSelected(_ item: SearchSuggestionItem) {
        hideSuggestions()
        onSuggestionSelected?(item)
    }
}

// MARK: - NSTextViewDelegate

extension SearchField: NSTextViewDelegate {
    func textDidChange(_: Notification) {
        let plainText = tokenTextView.getPlainText()
        if plainText != text {
            text = plainText
            onTextChanged?(plainText)
        }
        updateCancelButtonVisibility()
        updateSuggestions()
    }

    func textDidBeginEditing(_: Notification) {
        onBecomeFirstResponder?()
    }
}
