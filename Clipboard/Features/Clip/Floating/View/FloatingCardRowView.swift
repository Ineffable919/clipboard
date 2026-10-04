//
//  FloatingCardRowView.swift
//  Clipboard
//
//  浮动窗口的单行卡片视图
//

import AppKit
import SnapKit

// MARK: - FloatingCardRowView

final class FloatingCardRowView: NSView {
    // MARK: - Subviews

    private let selectionBorderView = NSView()
    private let backgroundView = NSView()

    private let appIconView = FloatingAppIconView()

    private let contentView = NSView()
    private var contentSubview: NSView?

    private let timestampLabel = NSTextField(labelWithString: "")
    private let chipTagIcon = NSImageView()

    // MARK: - Badge (Plain Text Indicator + Quick Paste)

    private let badgeBgView: BadgeBackgroundView = {
        let view = BadgeBackgroundView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 4.0
        view.layer?.cornerCurve = .continuous
        view.isHidden = true
        return view
    }()

    private let badgeStackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 0
        stack.distribution = .fill
        return stack
    }()

    private let plainTextIcon: NSImageView = {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "text.justify.leading", accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(textStyle: .caption1)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.isHidden = true
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)
        return icon
    }()

    private let quickPasteBadge: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: NSFont.labelFontSize, weight: .regular)
        label.textColor = .labelColor
        label.alignment = .center
        label.isHidden = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    // MARK: - State

    private(set) var currentModel: PasteboardModel?
    private var currentKeyword: String = ""
    private(set) var displayMode: FloatingDisplayMode = .standard
    private var isSelectedState: Bool = false
    private var isFocusedState: Bool = false
    private var iconLoadTask: Task<Void, Never>?
    private var contentLoadTask: Task<Void, Never>?

    // MARK: - Quick Paste

    var quickPasteIndex: Int? {
        didSet { updateQuickPasteBadge() }
    }

    var showPlainTextIndicator: Bool = false {
        didSet {
            plainTextIcon.isHidden = !showPlainTextIndicator
            updateBadgeVisibility()
        }
    }

    // MARK: - Callbacks

    var onPaste: (() -> Void)?
    var onPastePlainText: (() -> Void)?
    var onCopy: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onTogglePreview: (() -> Void)?
    var onAssignToChip: ((Int) -> Void)?
    var onCreateChip: ((PasteboardModel) -> Void)?

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
        let doubleClick = CollectionClickGestureRecognizer(target: self, action: #selector(handleDoubleClick))
        doubleClick.numberOfClicksRequired = 2
        doubleClick.delaysPrimaryMouseButtonEvents = false
        addGestureRecognizer(doubleClick)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit {
        iconLoadTask?.cancel()
        contentLoadTask?.cancel()
    }

    // MARK: - Configure

    func configure(
        with model: PasteboardModel,
        keyword: String,
        isSelected: Bool,
        isFocused: Bool,
        quickPasteIndex: Int?,
        displayMode: FloatingDisplayMode = .standard
    ) {
        let modeChanged = self.displayMode != displayMode
        self.displayMode = displayMode
        if modeChanged { applyDisplayMode() }
        let modelChanged = currentModel?.uniqueId != model.uniqueId
        currentModel = model
        currentKeyword = keyword

        let (bgColor, fgColor) = model.colors()
        let resolvedBg: NSColor = if model.cachedBackgroundColor != nil {
            bgColor
        } else {
            .controlBackgroundColor
        }
        backgroundView.layer?.backgroundColor = resolvedBg.cgColor

        timestampLabel.stringValue = model.timestamp.timeAgo(
            relativeTo: TimeManager.shared.currentTime
        )
        timestampLabel.textColor = fgColor
        if displayMode == .standard, modelChanged || modeChanged {
            appIconView.configure(appID: model.appID, appPath: model.appPath)
        }

        if let chip = model.getGroupChip() {
            chipTagIcon.contentTintColor = CategoryChip.nsColor(at: chip.colorIndex)
            chipTagIcon.isHidden = false
        } else {
            chipTagIcon.isHidden = true
        }

        if modelChanged || modeChanged {
            replaceContentSubview(for: model, keyword: keyword)
        } else {
            updateKeywordInContentSubview(keyword: keyword, model: model)
        }

        updateBadgeAppearance(for: model)

        self.quickPasteIndex = quickPasteIndex

        updateSelection(isSelected: isSelected, isFocused: isFocused)
    }

    func updateSelection(isSelected: Bool, isFocused: Bool) {
        isSelectedState = isSelected
        isFocusedState = isFocused
        applySelectionBorder()
    }

    private func applySelectionBorder() {
        guard let layer = selectionBorderView.layer else { return }
        guard isSelectedState else {
            layer.borderWidth = 0
            return
        }
        let color: NSColor = isFocusedState
            ? .controlAccentColor
            : .gray.withAlphaComponent(0.5)
        layer.borderColor = color.cgColor
        layer.borderWidth = FloatConst.floatSelectionBorderWidth
    }

    private func updateShadow() {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.shadowColor.withAlphaComponent(0.12)
        shadow.shadowBlurRadius = 2
        shadow.shadowOffset = CGSize(width: 0, height: -1)
        selectionBorderView.shadow = shadow
    }

    private func updateQuickPasteBadge() {
        if let idx = quickPasteIndex {
            quickPasteBadge.stringValue = "\(idx)"
            quickPasteBadge.isHidden = false
        } else {
            quickPasteBadge.isHidden = true
        }
        updateBadgeVisibility()
    }

    private func updateBadgeVisibility() {
        badgeBgView.isHidden = plainTextIcon.isHidden && quickPasteBadge.isHidden
    }

    private func updateBadgeAppearance(for model: PasteboardModel) {
        let (bgColor, tintColor) = model.colors()
        badgeBgView.dynamicBackgroundColor = bgColor
        plainTextIcon.contentTintColor = tintColor
        quickPasteBadge.textColor = tintColor
    }

    @objc private func handleDoubleClick() {
        onPaste?()
    }

    func updateTimestamp() {
        guard let model = currentModel else { return }
        timestampLabel.stringValue = model.timestamp.timeAgo(
            relativeTo: TimeManager.shared.currentTime
        )
    }

    // MARK: - Layout

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            applySelectionBorder()
            updateShadow()
            guard let model = currentModel else { return }
            let (bgColor, _) = model.colors()
            let resolvedBg: NSColor = model.cachedBackgroundColor != nil
                ? bgColor : .controlBackgroundColor
            backgroundView.layer?.backgroundColor = resolvedBg.cgColor
        }
    }

    // MARK: - Content Subview

    private func replaceContentSubview(for model: PasteboardModel, keyword: String) {
        contentLoadTask?.cancel()
        contentSubview?.removeFromSuperview()
        contentSubview = nil

        let view = makeContentSubview(for: model, keyword: keyword)
        contentView.addSubview(view)
        view.snp.makeConstraints { $0.edges.equalToSuperview() }
        contentSubview = view
    }

    private func updateKeywordInContentSubview(keyword: String, model: PasteboardModel) {
        switch contentSubview {
        case let view as FloatingTextContentView:
            view.update(keyword: keyword, model: model)
        case let view as FloatingRichContentView:
            view.update(keyword: keyword, model: model)
        default:
            break
        }
    }

    // MARK: - Context Menu

    private func setupContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        self.menu = menu
    }
}

private extension FloatingCardRowView {
    // MARK: - Setup

    func setup() {
        wantsLayer = true

        selectionBorderView.wantsLayer = true
        selectionBorderView.layer?.cornerRadius = displayMode.cardRadius + FloatConst.floatSelectionBorderWidth
        selectionBorderView.layer?.cornerCurve = .continuous
        selectionBorderView.layer?.borderWidth = 0
        selectionBorderView.layer?.backgroundColor = .clear
        selectionBorderView.layer?.masksToBounds = false

        addSubview(selectionBorderView)

        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = displayMode.cardRadius
        backgroundView.layer?.cornerCurve = .continuous
        backgroundView.layer?.masksToBounds = true
        selectionBorderView.addSubview(backgroundView)

        backgroundView.addSubview(appIconView)

        contentView.wantsLayer = true
        contentView.layer?.masksToBounds = true
        backgroundView.addSubview(contentView)

        timestampLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        timestampLabel.textColor = .secondaryLabelColor
        timestampLabel.alignment = .right
        timestampLabel.lineBreakMode = .byTruncatingTail
        timestampLabel.setContentHuggingPriority(.required, for: .horizontal)
        timestampLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        backgroundView.addSubview(timestampLabel)

        badgeBgView.addSubview(badgeStackView)
        badgeStackView.addArrangedSubview(plainTextIcon)
        badgeStackView.addArrangedSubview(quickPasteBadge)
        backgroundView.addSubview(badgeBgView, positioned: .above, relativeTo: contentView)

        chipTagIcon.imageScaling = .scaleProportionallyUpOrDown
        chipTagIcon.image = NSImage(systemSymbolName: "tag.fill", accessibilityDescription: nil)
        chipTagIcon.isHidden = true
        backgroundView.addSubview(chipTagIcon)

        selectionBorderView.snp.makeConstraints { make in
            make.edges.equalToSuperview().priority(999)
        }

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(FloatConst.floatSelectionBorderWidth).priority(999)
        }

        badgeStackView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(Const.space2)
        }

        applyDisplayMode()

        setupContextMenu()
        updateShadow()
    }

    func applyDisplayMode() {
        let isStandard = displayMode == .standard
        appIconView.isHidden = !isStandard
        timestampLabel.isHidden = !isStandard
        timestampLabel.font = .systemFont(ofSize: NSFont.labelFontSize)
        selectionBorderView.layer?.cornerRadius = displayMode.cardRadius + FloatConst.floatSelectionBorderWidth
        backgroundView.layer?.cornerRadius = displayMode.cardRadius

        badgeBgView.snp.remakeConstraints { make in
            make.trailing.equalToSuperview().inset(Const.space6)
            make.height.equalTo(16)
            if isStandard {
                make.bottom.equalToSuperview().inset(Const.space4)
            } else {
                make.centerY.equalToSuperview()
            }
        }

        appIconView.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(Const.space6)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(28)
        }
        timestampLabel.snp.remakeConstraints { make in
            make.trailing.equalToSuperview().inset(Const.space6)
            make.centerY.equalToSuperview()
        }
        chipTagIcon.snp.remakeConstraints { make in
            make.trailing.equalToSuperview().inset(isStandard ? Const.space4 : Const.space2)
            make.top.equalToSuperview().offset(isStandard ? Const.space4 : Const.space2)
            make.width.height.equalTo(isStandard ? 10 : 8)
        }
        contentView.snp.remakeConstraints { make in
            if isStandard {
                make.leading.equalTo(appIconView.snp.trailing).offset(Const.space10)
                make.trailing.equalTo(timestampLabel.snp.leading).offset(-Const.space4)
                make.top.bottom.equalToSuperview().inset(Const.space4)
            } else {
                make.leading.trailing.equalToSuperview().inset(Const.space10)
                make.top.bottom.equalToSuperview().inset(Const.space8)
            }
        }
    }
}
