//
//  ClipPreviewPopoverViewController.swift
//  Clipboard
//
//  预览 Popover 的主 ViewController
//

import AppKit
import SnapKit

// MARK: - ClipPreviewPopoverViewController

final class ClipPreviewPopoverViewController: NSViewController {
    // MARK: - State

    private var model: PasteboardModel?
    private var appIcon: NSImage?
    private var defaultBrowserName: String?
    private var defaultAppForFile: String?
    private var fileSize: String?
    private var metadataTask: Task<Void, Never>?

    // MARK: - Callbacks

    var onContentInteraction: (() -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - Subviews

    private let headerView = PreviewHeaderBar()
    private let contentView = ClipPreviewContentView()
    private let footerView = PreviewFooterBar()

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()

        contentView.onMouseDown = { [weak self] in
            self?.onContentInteraction?()
        }
    }

    // MARK: - Public API

    @discardableResult
    func configure(with model: PasteboardModel) -> NSSize {
        self.model = model

        headerView.configure(model: model, appIcon: nil)
        contentView.configure(with: model)
        footerView.configure(model: model, fileSize: nil, browserName: nil, defaultAppForFile: nil)

        let size = preferredSize(for: model)
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()

        metadataTask = Task { @MainActor [weak self] in
            await self?.loadMetadata(for: model)
        }

        return size
    }

    func cleanup() {
        metadataTask?.cancel()
        metadataTask = nil
        contentView.reset()
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(headerView)
        view.addSubview(contentView)
        view.addSubview(footerView)

        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(Const.space12)
            make.height.equalTo(24)
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom).offset(Const.space8)
            make.leading.trailing.equalToSuperview().inset(Const.space12)
            make.bottom.equalTo(footerView.snp.top).offset(-Const.space8)
        }

        footerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Const.space12)
            make.bottom.equalToSuperview().inset(Const.space12)
            make.height.greaterThanOrEqualTo(24)
        }

        headerView.onClose = { [weak self] in
            self?.dismissPopover()
        }
        headerView.onEdit = { [weak self] in
            guard let model = self?.model else { return }
            self?.dismissPopover()
            EditWindowController.shared.openWindow(with: model)
        }
        headerView.onOpenWithApp = { [weak self] in
            guard let path = self?.model?.cachedFilePaths?.first else { return }
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
        footerView.onShowInFinder = { [weak self] in
            guard let path = self?.model?.cachedFilePaths?.first else { return }
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        }
        footerView.onOpenInBrowser = { [weak self] in
            guard let url = self?.model?.attributeString.string.asCompleteURL() else { return }
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Size calculation

    func preferredSize(for model: PasteboardModel) -> NSSize {
        let width = clampedWidth(for: model)
        let contentH = ClipPreviewContentView.preferredContentHeight(
            for: model,
            width: width - Const.space12 * 2
        )
        let totalH = 24 + Const.space8 + contentH + Const.space8 + 24 + Const.space12 * 2
        let clampedH = min(max(totalH, Const.minPreviewHeight), Const.maxPreviewHeight)
        return NSSize(width: width, height: clampedH)
    }

    private func clampedWidth(for model: PasteboardModel) -> CGFloat {
        switch model.type {
        case .color:
            return 500
        case .file, .link:
            return Const.maxPreviewWidth
        case .image:
            guard let size = model.cachedImageSize, size.width > 0 else {
                return Const.maxPreviewWidth
            }
            let scale = min(
                Const.maxPreviewWidth / size.width,
                Const.maxContentHeight / size.height,
                1.0
            )
            let displayW = ceil(size.width * scale) + Const.space12 * 2
            return min(max(displayW, Const.minPreviewWidth), Const.maxPreviewWidth)
        case .string, .rich:
            let textWidth = estimatedTextWidth(for: model)
            return min(max(textWidth + Const.space12 * 2 + Const.space8 * 2, Const.minPreviewWidth), Const.maxPreviewWidth)
        case .none:
            return Const.minPreviewWidth
        }
    }

    private func estimatedTextWidth(for model: PasteboardModel) -> CGFloat {
        let attributed = model.attributeString
        guard attributed.length > 0 else { return Const.minPreviewWidth }

        let maxW = Const.maxPreviewWidth - Const.space12 * 2 - Const.space8 * 2
        let rect = attributed.boundingRect(
            with: NSSize(width: maxW, height: Const.maxContentHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return min(ceil(rect.width) + 32, maxW)
    }

    // MARK: - Metadata loading

    private func loadMetadata(for model: PasteboardModel) async {
        guard !Task.isCancelled else { return }

        if !model.appPath.isEmpty {
            appIcon = NSWorkspace.shared.icon(forFile: model.appPath)
        }

        defaultBrowserName = bundleDisplayName(
            for: NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://")!)
        )

        let isSingleFile = model.type == .file && model.fileSize() == 1
        if isSingleFile, let filePath = model.cachedFilePaths?.first {
            let url = URL(fileURLWithPath: filePath)
            defaultAppForFile = bundleDisplayName(
                for: NSWorkspace.shared.urlForApplication(toOpen: url)
            )
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path()),
               let size = attrs[.size] as? Int64
            {
                fileSize = size.formatted(.byteCount(style: .file))
            }
        }

        guard !Task.isCancelled else { return }

        headerView.configure(model: model, appIcon: appIcon)
        footerView.configure(
            model: model,
            fileSize: fileSize,
            browserName: defaultBrowserName,
            defaultAppForFile: defaultAppForFile
        )
        headerView.updateOpenWithApp(
            isSingleFile: isSingleFile,
            defaultAppForFile: defaultAppForFile
        )
    }

    private func bundleDisplayName(for appURL: URL?) -> String? {
        guard let appURL, let bundle = Bundle(url: appURL) else { return nil }
        return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
    }

    // MARK: - Dismiss

    private func dismissPopover() {
        onDismiss?()
    }
}

// MARK: - PreviewHeaderBar

final class PreviewHeaderBar: NSView {
    var onClose: (() -> Void)?
    var onEdit: (() -> Void)?
    var onOpenWithApp: (() -> Void)?

    private let closeButton: NSButton = {
        let btn = NSButton()
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
        btn.contentTintColor = .secondaryLabelColor
        return btn
    }()

    private let appIconView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.isHidden = true
        return iv
    }()

    private let appNameLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = .systemFont(ofSize: NSFont.systemFontSize)
        f.textColor = .secondaryLabelColor
        f.lineBreakMode = .byTruncatingTail
        return f
    }()

    private let editButton: PreviewPillButton = {
        let btn = PreviewPillButton(title: String(localized: .edit))
        btn.isHidden = true
        return btn
    }()

    private let openWithButton: PreviewPillButton = {
        let btn = PreviewPillButton()
        btn.isHidden = true
        return btn
    }()

    override init(frame: NSRect) {
        super.init(frame: frame)
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        editButton.onAction = { [weak self] in self?.editTapped() }
        openWithButton.onAction = { [weak self] in self?.openWithTapped() }
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    private func setupLayout() {
        addSubview(closeButton)
        addSubview(appIconView)
        addSubview(appNameLabel)
        addSubview(editButton)
        addSubview(openWithButton)

        closeButton.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }

        appIconView.snp.makeConstraints { make in
            make.leading.equalTo(closeButton.snp.trailing).offset(Const.space6)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(18)
        }

        appNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(appIconView.snp.trailing).offset(Const.space4)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(editButton.snp.leading).offset(-Const.space8)
        }

        editButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        openWithButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
    }

    func configure(model: PasteboardModel, appIcon: NSImage?) {
        appNameLabel.stringValue = model.appName

        if let icon = appIcon {
            appIconView.image = icon
            appIconView.isHidden = false
        } else {
            appIconView.isHidden = true
        }

        editButton.isHidden = !model.pasteboardType.isText()
    }

    func updateOpenWithApp(isSingleFile: Bool, defaultAppForFile: String?) {
        if isSingleFile, let appName = defaultAppForFile {
            openWithButton.title = String(localized: .openWithApp(appName))
            openWithButton.isHidden = false
        } else {
            openWithButton.isHidden = true
        }
    }

    @objc private func closeTapped() {
        onClose?()
    }

    private func editTapped() {
        onEdit?()
    }

    private func openWithTapped() {
        onOpenWithApp?()
    }
}

// MARK: - PreviewFooterBar

final class PreviewFooterBar: NSView {
    var onShowInFinder: (() -> Void)?
    var onOpenInBrowser: (() -> Void)?

    private let firstLineLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = .systemFont(ofSize: NSFont.systemFontSize)
        f.textColor = .secondaryLabelColor
        f.lineBreakMode = .byCharWrapping
        f.maximumNumberOfLines = 1
        return f
    }()

    private let secondLineLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = .systemFont(ofSize: NSFont.systemFontSize)
        f.textColor = .secondaryLabelColor
        f.lineBreakMode = .byTruncatingHead
        f.maximumNumberOfLines = 1
        return f
    }()

    private lazy var infoStack: NSStackView = {
        let sv = NSStackView(views: [firstLineLabel, secondLineLabel])
        sv.orientation = .vertical
        sv.alignment = .leading
        sv.spacing = 0
        sv.distribution = .fill
        return sv
    }()

    private let fileSizeLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = .systemFont(ofSize: NSFont.systemFontSize)
        f.textColor = .secondaryLabelColor
        f.isHidden = true
        return f
    }()

    private let finderButton: PreviewPillButton = {
        let btn = PreviewPillButton(title: String(localized: .showInFinder))
        btn.isHidden = true
        return btn
    }()

    private let browserButton: PreviewPillButton = {
        let btn = PreviewPillButton()
        btn.isHidden = true
        return btn
    }()

    override init(frame: NSRect) {
        super.init(frame: frame)
        finderButton.onAction = { [weak self] in self?.finderTapped() }
        browserButton.onAction = { [weak self] in self?.browserTapped() }
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    private func setupLayout() {
        addSubview(infoStack)
        addSubview(fileSizeLabel)
        addSubview(finderButton)
        addSubview(browserButton)

        infoStack.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(fileSizeLabel.snp.leading).offset(-Const.space8)
            make.width.lessThanOrEqualTo((Const.maxPreviewWidth - Const.space12 * 2) * 0.7)
        }

        fileSizeLabel.snp.makeConstraints { make in
            make.trailing.equalTo(finderButton.snp.leading).offset(-Const.space6)
            make.centerY.equalToSuperview()
        }

        finderButton.snp.makeConstraints { make in
            make.trailing.equalTo(browserButton.snp.leading).offset(-Const.space6)
            make.centerY.equalToSuperview()
        }

        browserButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
    }

    func configure(
        model: PasteboardModel,
        fileSize: String?,
        browserName: String?,
        defaultAppForFile _: String?
    ) {
        let isSingleFile = model.type == .file && model.fileSize() == 1
        let showLinkPreview = model.type == .link
            && PasteUserDefaults.enableLinkPreview
            && model.isLink

        if isSingleFile, let path = model.cachedFilePaths?.first {
            let maxWidth = (Const.maxPreviewWidth - Const.space12 * 2) * 0.7
            let font = firstLineLabel.font ?? .systemFont(ofSize: NSFont.systemFontSize)
            let (line1, line2) = splitPathIntoTwoLines(path, font: font, maxWidth: maxWidth)
            firstLineLabel.stringValue = line1
            secondLineLabel.stringValue = line2
            secondLineLabel.isHidden = line2.isEmpty
        } else if model.pasteboardType.isText(), !showLinkPreview {
            let stats = TextStatistics(from: model.attributeString.string)
            firstLineLabel.stringValue = stats.displayString
            secondLineLabel.stringValue = ""
            secondLineLabel.isHidden = true
        } else {
            firstLineLabel.stringValue = model.introString()
            secondLineLabel.stringValue = ""
            secondLineLabel.isHidden = true
        }

        if isSingleFile, let size = fileSize {
            fileSizeLabel.stringValue = size
            fileSizeLabel.isHidden = false
        } else {
            fileSizeLabel.isHidden = true
        }

        finderButton.isHidden = !isSingleFile

        if showLinkPreview, let name = browserName {
            browserButton.title = String(localized: .openInApp(name))
            browserButton.isHidden = false
        } else {
            browserButton.isHidden = true
        }
    }

    // MARK: - Private

    private func splitPathIntoTwoLines(_ text: String, font: NSFont, maxWidth: CGFloat) -> (String, String) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        guard (text as NSString).size(withAttributes: attrs).width > maxWidth else {
            return (text, "")
        }

        let chars = Array(text)
        var lo = 0
        var hi = chars.count
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            let sub = String(chars[..<mid])
            if (sub as NSString).size(withAttributes: attrs).width <= maxWidth {
                lo = mid
            } else {
                hi = mid - 1
            }
        }

        return (String(chars[..<lo]), String(chars[lo...]))
    }

    private func finderTapped() {
        onShowInFinder?()
    }

    private func browserTapped() {
        onOpenInBrowser?()
    }
}
