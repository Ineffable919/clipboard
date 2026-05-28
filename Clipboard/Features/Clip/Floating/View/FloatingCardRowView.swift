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
    private let quickPasteBadge = NSTextField(labelWithString: "")
    private let chipTagIcon = NSImageView()

    // MARK: - State

    private var currentModel: PasteboardModel?
    private var currentKeyword: String = ""
    private var isSelectedState: Bool = false
    private var isFocusedState: Bool = false
    private var iconLoadTask: Task<Void, Never>?
    private var contentLoadTask: Task<Void, Never>?

    // MARK: - Quick Paste

    var quickPasteIndex: Int? {
        didSet { updateQuickPasteBadge() }
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
        selectionBorderView.layer?.cornerRadius = Const.radius + FloatConst.floatSelectionBorderWidth
        selectionBorderView.layer?.cornerCurve = .continuous
        selectionBorderView.layer?.borderWidth = 0
        selectionBorderView.layer?.backgroundColor = .clear
        selectionBorderView.layer?.masksToBounds = false

        addSubview(selectionBorderView)

        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = Const.radius
        backgroundView.layer?.cornerCurve = .continuous
        backgroundView.layer?.masksToBounds = true
        selectionBorderView.addSubview(backgroundView)

        backgroundView.addSubview(appIconView)

        contentView.wantsLayer = true
        contentView.layer?.masksToBounds = true
        backgroundView.addSubview(contentView)

        timestampLabel.font = .systemFont(ofSize: NSFont.labelFontSize, weight: .regular)
        timestampLabel.textColor = .secondaryLabelColor
        timestampLabel.lineBreakMode = .byTruncatingTail
        timestampLabel.setContentHuggingPriority(.required, for: .horizontal)
        timestampLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        backgroundView.addSubview(timestampLabel)

        // 快速粘贴角标
        quickPasteBadge.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        quickPasteBadge.textColor = .labelColor
        quickPasteBadge.alignment = .right
        quickPasteBadge.isHidden = true
        backgroundView.addSubview(quickPasteBadge)

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

        appIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Const.space6)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(28)
        }

        timestampLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Const.space6)
            make.centerY.equalToSuperview()
        }

        quickPasteBadge.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Const.space6)
            make.bottom.equalToSuperview().offset(-Const.space4)
        }

        chipTagIcon.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Const.space4)
            make.top.equalToSuperview().offset(Const.space4)
            make.width.height.equalTo(10)
        }

        contentView.snp.makeConstraints { make in
            make.leading.equalTo(appIconView.snp.trailing).offset(Const.space10)
            make.trailing.equalTo(timestampLabel.snp.leading).offset(-Const.space4)
            make.top.equalToSuperview().offset(Const.space4)
            make.bottom.equalToSuperview().offset(-Const.space4)
        }

        setupContextMenu()
        updateShadow()
    }

    // MARK: - Configure

    func configure(
        with model: PasteboardModel,
        keyword: String,
        isSelected: Bool,
        isFocused: Bool,
        quickPasteIndex: Int?
    ) {
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

        if modelChanged {
            appIconView.configure(appPath: model.appPath)
        }

        if let chip = model.getGroupChip() {
            chipTagIcon.contentTintColor = CategoryChip.nsColor(at: chip.colorIndex)
            chipTagIcon.isHidden = false
        } else {
            chipTagIcon.isHidden = true
        }

        if modelChanged {
            replaceContentSubview(for: model, keyword: keyword)
        } else {
            updateKeywordInContentSubview(keyword: keyword, model: model)
        }

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
        guard let layer = selectionBorderView.layer else { return }
        layer.shadowColor = NSColor.shadowColor.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 2
        layer.shadowOffset = CGSize(width: 0, height: -1)
    }

    private func updateQuickPasteBadge() {
        if let idx = quickPasteIndex {
            quickPasteBadge.stringValue = "\(idx)"
            quickPasteBadge.isHidden = false
            if let model = currentModel {
                quickPasteBadge.textColor = model.colors().1
            }
        } else {
            quickPasteBadge.isHidden = true
        }
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
            return FloatingImageContentView(model: model)
        case .file:
            return FloatingFileContentView(model: model)
        case .rich:
            if model.hasBgColor {
                return FloatingRichContentView(model: model, keyword: keyword)
            }
            return FloatingTextContentView(model: model, keyword: keyword)
        case .link:
            if PasteUserDefaults.enableLinkPreview {
                return FloatingLinkContentView(model: model, keyword: keyword)
            }
            return FloatingTextContentView(model: model, keyword: keyword)
        case .string:
            return FloatingTextContentView(model: model, keyword: keyword)
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
        let pasteTitle: String
        if let appName = AppEnvironment.shared.previousApp?.localizedName, PasteUserDefaults.pasteDirect {
            pasteTitle = String(localized: .pasteToApp(appName))
        } else {
            pasteTitle = String(localized: .paste)
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

// MARK: - VerticallyCenteredTextFieldCell

private final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let rect = super.drawingRect(forBounds: rect)
        let textSize = cellSize(forBounds: rect)
        let heightDelta = rect.height - textSize.height
        guard heightDelta > 0 else { return rect }
        return NSRect(
            x: rect.origin.x,
            y: rect.origin.y + heightDelta / 2,
            width: rect.width,
            height: textSize.height
        )
    }
}

// MARK: - FloatingTextContentView

final class FloatingTextContentView: NSView {
    private let textField: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.cell = VerticallyCenteredTextFieldCell()
        return field
    }()

    init(model: PasteboardModel, keyword: String) {
        super.init(frame: .zero)
        textField.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textField.lineBreakMode = .byTruncatingTail
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
        if keyword.isEmpty {
            textField.attributedStringValue = model.plainTextAttributedString
        } else {
            textField.attributedStringValue = model.highlightedNSAttributedString(keyword: keyword)
        }
    }
}

// MARK: - FloatingRichContentView

final class FloatingRichContentView: NSView {
    private let textField: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.cell = VerticallyCenteredTextFieldCell()
        return field
    }()

    init(model: PasteboardModel, keyword: String) {
        super.init(frame: .zero)
        textField.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 2
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
    private let imageView = NSImageView()
    private let placeholder = NSImageView()
    private var loadTask: Task<Void, Never>?

    init(model: PasteboardModel) {
        super.init(frame: .zero)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.isHidden = true
        addSubview(imageView)
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }

        placeholder.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
        placeholder.contentTintColor = .secondaryLabelColor
        placeholder.imageScaling = .scaleProportionallyUpOrDown
        addSubview(placeholder)
        placeholder.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(20)
        }

        loadTask = Task { @MainActor [weak self] in
            let image = await model.loadThumbnail()
            guard !Task.isCancelled, let self else { return }
            if let image {
                imageView.image = image
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

    init(model: PasteboardModel, keyword: String) {
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

        let urlString = model.attributeString.string
        if keyword.isEmpty {
            urlLabel.stringValue = urlString
        } else {
            urlLabel.attributedStringValue = model.highlightedPlainText(keyword: keyword)
        }

        if let cached = model.cachedLinkMetadata {
            applyMetadata(title: cached.title, icon: cached.iconImage, urlString: urlString)
        } else {
            titleLabel.stringValue = URL(string: urlString)?.host() ?? urlString
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
        titleLabel.stringValue = title ?? URL(string: urlString)?.host() ?? urlString
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
