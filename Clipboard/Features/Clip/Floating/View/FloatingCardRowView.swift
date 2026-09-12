//
//  FloatingCardRowView.swift
//  Clipboard
//
//  浮动窗口的单行卡片视图
//

import AppKit
@preconcurrency import LinkPresentation
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
        let iv = NSImageView()
        iv.image = NSImage(systemSymbolName: "text.justify.leading", accessibilityDescription: nil)
        iv.symbolConfiguration = NSImage.SymbolConfiguration(textStyle: .caption1)
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.isHidden = true
        iv.setContentHuggingPriority(.required, for: .horizontal)
        iv.setContentCompressionResistancePriority(.required, for: .horizontal)
        return iv
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

    private var currentModel: PasteboardModel?
    private var currentKeyword: String = ""
    private var displayMode: FloatingDisplayMode = .standard
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
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit {
        iconLoadTask?.cancel()
        contentLoadTask?.cancel()
    }

    // MARK: - Setup

    private func setup() {
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

    private func applyDisplayMode() {
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
            appIconView.configure(appPath: model.appPath)
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

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if event.type == .leftMouseDown, event.clickCount == 2 {
            onPaste?()
        }
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
        case let v as FloatingTextContentView:
            v.update(keyword: keyword, model: model)
        case let v as FloatingRichContentView:
            v.update(keyword: keyword, model: model)
        default:
            break
        }
    }

    private func makeContentSubview(for model: PasteboardModel, keyword: String) -> NSView {
        switch model.type {
        case .color:
            return FloatingColorContentView(model: model)
        case .image:
            return FloatingImageContentView(model: model, displayMode: displayMode)
        case .file:
            return FloatingFileContentView(model: model)
        case .rich:
            if model.hasBgColor {
                return FloatingRichContentView(
                    model: model, keyword: keyword, maximumLines: displayMode == .standard ? 2 : 1
                )
            }
            return FloatingTextContentView(
                model: model, keyword: keyword, maximumLines: displayMode == .standard ? 0 : 1
            )
        case .link:
            if PasteUserDefaults.enableLinkPreview {
                return FloatingLinkContentView(model: model, keyword: keyword, displayMode: displayMode)
            }
            return FloatingTextContentView(
                model: model, keyword: keyword, maximumLines: displayMode == .standard ? 0 : 1
            )
        case .string:
            return FloatingTextContentView(
                model: model, keyword: keyword, maximumLines: displayMode == .standard ? 0 : 1
            )
        case .none:
            return NSView()
        }
    }

    // MARK: - Context Menu

    private func setupContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        self.menu = menu
    }
}

// MARK: - ClipItemMenuActionable

extension FloatingCardRowView: ClipItemMenuActionable {
    func handleClipPaste() {
        onPaste?()
    }

    func handleClipPastePlain() {
        onPastePlainText?()
    }

    func handleClipCopy() {
        onCopy?()
    }

    func handleClipEdit() {
        onEdit?()
    }

    func handleClipDelete() {
        onDelete?()
    }

    func handleClipPreview() {
        onTogglePreview?()
    }

    func handleClipAssignToChip(_ sender: NSMenuItem) {
        guard let model = currentModel, model.group != sender.tag else { return }
        onAssignToChip?(sender.tag)
    }

    func handleClipCreateChip() {
        guard let model = currentModel else { return }
        onCreateChip?(model)
    }

    func handleClipUnpin() {
        onAssignToChip?(-1)
    }

    func handleClipRevealInFinder() {
        guard let paths = currentModel?.cachedFilePaths, !paths.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(paths.map { URL(fileURLWithPath: $0) })
    }

    func handleClipOpenInBrowser() {
        guard let model = currentModel, let url = URL(string: model.plainText) else { return }
        NSWorkspace.shared.open(url)
    }

    func handleClipOpenWithDefaultApp() {
        guard let path = currentModel?.cachedFilePaths?.first else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
}

// MARK: - NSMenuDelegate

extension FloatingCardRowView: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let model = currentModel else { return }
        let pasteTitle = if let appName = AppEnvironment.shared.previousApp?.localizedName, PasteUserDefaults.pasteDirect {
            String(localized: .pasteToApp(appName))
        } else {
            String(localized: .paste)
        }
        for item in buildClipItemMenu(for: model, pasteTitle: pasteTitle).items {
            menu.addItem(item)
        }
    }
}

// MARK: - FloatingAppIconView

private final class FloatingAppIconView: NSView {
    private let imageView = NSImageView()
    private var loadTask: Task<Void, Never>?

    override init(frame: NSRect) {
        super.init(frame: frame)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(imageView)
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit { loadTask?.cancel() }

    func configure(appPath: String) {
        loadTask?.cancel()
        imageView.image = nil
        loadTask = Task { @MainActor [weak self] in
            let icon = await AppIconCache.shared.loadIcon(forPath: appPath)
            guard !Task.isCancelled else { return }
            self?.imageView.image = icon
        }
    }
}

// MARK: - FloatingTextContentView

final class FloatingTextContentView: NSView {
    private let textField = NSTextField(labelWithString: "")

    init(model: PasteboardModel, keyword: String, maximumLines: Int) {
        super.init(frame: .zero)
        textField.cell = VerticallyCenteredTextFieldCell()
        textField.cell?.usesSingleLineMode = maximumLines == 1
        textField.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = maximumLines
        textField.cell?.truncatesLastVisibleLine = true
        addSubview(textField)
        textField.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        update(keyword: keyword, model: model)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func update(keyword: String, model: PasteboardModel) {
        let text = keyword.isEmpty
            ? model.plainTextAttributedString
            : model.highlightedNSAttributedString(keyword: keyword)
        if textField.maximumNumberOfLines == 1, model.pasteboardType == .string {
            let preview = NSMutableAttributedString(attributedString: text)
            preview.addAttribute(
                .font, value: NSFont.systemFont(ofSize: 12), range: NSRange(location: 0, length: preview.length)
            )
            textField.attributedStringValue = preview
        } else {
            textField.attributedStringValue = text
        }
    }
}

// MARK: - FloatingRichContentView

final class FloatingRichContentView: NSView {
    private let textField = NSTextField(labelWithString: "")

    init(model: PasteboardModel, keyword: String, maximumLines: Int) {
        super.init(frame: .zero)
        textField.cell = VerticallyCenteredTextFieldCell()
        textField.cell?.usesSingleLineMode = maximumLines == 1
        textField.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = maximumLines
        textField.cell?.truncatesLastVisibleLine = true
        addSubview(textField)
        textField.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        update(keyword: keyword, model: model)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func update(keyword: String, model: PasteboardModel) {
        textField.attributedStringValue = model.highlightedRichText(keyword: keyword)
    }
}

// MARK: - FloatingColorContentView

private final class FloatingColorContentView: NSView {
    private let label = NSTextField(labelWithString: "")

    init(model: PasteboardModel) {
        super.init(frame: .zero)
        label.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.textColor = model.colors().1
        label.stringValue = model.colorDisplayText
        addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}

// MARK: - FloatingImageContentView

private final class FloatingImageContentView: NSView {
    private let imageView = NSView()
    private let placeholder = NSImageView()
    private var loadTask: Task<Void, Never>?

    init(model: PasteboardModel, displayMode: FloatingDisplayMode) {
        super.init(frame: .zero)
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = displayMode == .standard ? 0 : 4
        imageView.layer?.masksToBounds = true
        imageView.layer?.contentsGravity = displayMode == .standard ? .resizeAspect : .resizeAspectFill
        imageView.isHidden = true
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            if displayMode == .standard {
                make.edges.equalToSuperview()
            } else {
                make.leading.centerY.equalToSuperview()
                make.width.equalTo(64)
                make.height.equalToSuperview()
            }
        }

        if displayMode == .minimal {
            let photoIcon = NSImageView()
            photoIcon.image = NSImage(
                systemSymbolName: "photo", accessibilityDescription: String(localized: .image)
            )
            photoIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            photoIcon.contentTintColor = .systemBlue
            photoIcon.imageScaling = .scaleNone
            addSubview(photoIcon)
            photoIcon.snp.makeConstraints { make in
                make.leading.equalTo(imageView.snp.trailing).offset(Const.space8)
                make.centerY.equalToSuperview()
                make.width.height.equalTo(20)
            }
        }

        placeholder.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
        placeholder.contentTintColor = .secondaryLabelColor
        placeholder.imageScaling = .scaleProportionallyUpOrDown
        addSubview(placeholder)
        placeholder.snp.makeConstraints { make in
            make.center.equalTo(imageView)
            make.width.height.equalTo(20)
        }

        loadTask = Task { @MainActor [weak self] in
            let image = await model.loadThumbnail()
            guard !Task.isCancelled, let self else { return }
            if let image {
                imageView.layer?.contents = image
                imageView.isHidden = false
                placeholder.isHidden = true
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit { loadTask?.cancel() }
}

// MARK: - FloatingFileContentView

private final class FloatingFileContentView: NSView {
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")

    init(model: PasteboardModel) {
        super.init(frame: .zero)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }

        nameLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.maximumNumberOfLines = 1
        addSubview(nameLabel)
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Const.space6)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        if let paths = model.cachedFilePaths, !paths.isEmpty {
            if paths.count > 1 {
                iconView.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
                iconView.contentTintColor = NSColor.controlAccentColor.withAlphaComponent(0.7)
                nameLabel.stringValue = String(localized: .fileCount(paths.count))
            } else if let path = paths.first {
                let url = URL(filePath: path)
                iconView.image = FileThumbnailService.shared.systemIcon(for: url)
                nameLabel.stringValue = url.lastPathComponent
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}

// MARK: - FloatingLinkContentView

private final class FloatingLinkContentView: NSView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let urlLabel = NSTextField(labelWithString: "")
    private var loadTask: Task<Void, Never>?
    private let displayMode: FloatingDisplayMode

    init(model: PasteboardModel, keyword: String, displayMode: FloatingDisplayMode) {
        self.displayMode = displayMode
        super.init(frame: .zero)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
        iconView.contentTintColor = .secondaryLabelColor
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        addSubview(textStack)
        textStack.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Const.space6)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        urlLabel.font = .systemFont(ofSize: NSFont.labelFontSize, weight: .regular)
        urlLabel.textColor = .secondaryLabelColor
        urlLabel.lineBreakMode = .byTruncatingMiddle
        urlLabel.maximumNumberOfLines = 1

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(urlLabel)
        if displayMode == .minimal {
            urlLabel.isHidden = true
            titleLabel.snp.makeConstraints { $0.width.equalTo(textStack) }
        }

        let urlString = model.attributeString.string
        if keyword.isEmpty {
            urlLabel.stringValue = urlString
        } else {
            urlLabel.attributedStringValue = model.highlightedPlainText(keyword: keyword)
        }

        if let cached = model.cachedLinkMetadata {
            applyMetadata(title: cached.title, icon: cached.iconImage, urlString: urlString)
        } else {
            applyMetadata(title: nil, icon: nil, urlString: urlString)
            loadTask = Task { @MainActor [weak self] in
                guard let url = URL(string: urlString) else { return }
                let metadata = await FloatingLinkContentView.fetchMetadata(for: url)
                guard !Task.isCancelled, let self else { return }
                model.cachedLinkMetadata = metadata
                applyMetadata(title: metadata.title, icon: metadata.iconImage, urlString: urlString)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit { loadTask?.cancel() }

    private func applyMetadata(title: String?, icon: NSImage?, urlString: String) {
        let title = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        titleLabel.stringValue = title.flatMap { $0.isEmpty ? nil : $0 }
            ?? URL(string: urlString)?.host() ?? urlString
        if displayMode == .minimal {
            toolTip = "\(titleLabel.stringValue)\n\(urlString)"
        }
        if let icon {
            iconView.image = icon
            iconView.contentTintColor = nil
        }
    }

    @preconcurrency
    private static func fetchMetadata(for url: URL) async -> LinkPreviewMetadata {
        let provider = LPMetadataProvider()
        provider.timeout = 5.0
        nonisolated(unsafe) let unsafeProvider = provider
        do {
            let metadata = try await withTaskCancellationHandler {
                try await provider.startFetchingMetadata(for: url)
            } onCancel: {
                unsafeProvider.cancel()
            }
            let icon: NSImage? = await withCheckedContinuation { cont in
                if let p = metadata.iconProvider ?? metadata.imageProvider {
                    p.loadObject(ofClass: NSImage.self) { img, _ in
                        cont.resume(returning: img as? NSImage)
                    }
                } else {
                    cont.resume(returning: nil)
                }
            }
            return LinkPreviewMetadata(title: metadata.title, previewImage: nil, iconImage: icon)
        } catch {
            return LinkPreviewMetadata(title: nil, previewImage: nil, iconImage: nil)
        }
    }
}
