//
//  ClipPreviewController.swift
//  Clipboard
//
//  预览 ViewController：组装 header/content/footer 布局
//

import AppKit
import SnapKit

// MARK: - ClipPreviewController

final class ClipPreviewController: NSViewController {
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
    var onPinToChip: ((PasteboardModel, Int) -> Void)?
    var onUnpin: ((PasteboardModel) -> Void)?
    var onCreateChip: ((PasteboardModel) -> Void)?

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
        bindActions()

        contentView.onMouseDown = { [weak self] in
            guard let self else { return }
            onContentInteraction?()
            view.window?.makeFirstResponder(contentView)
        }
    }

    // MARK: - Public API

    @discardableResult
    func configure(with model: PasteboardModel, maxHeight: CGFloat = Const.maxPreviewHeight) -> NSSize {
        metadataTask?.cancel()
        metadataTask = nil

        self.model = model
        appIcon = nil
        defaultBrowserName = nil
        defaultAppForFile = nil
        fileSize = nil

        let cappedH = min(Const.maxPreviewHeight, maxHeight)
        let maxContentH = max(cappedH - ClipPreviewPopover.chrome, 0)

        headerView.configure(model: model, appIcon: nil)
        contentView.configure(with: model, maxContentH: maxContentH)
        headerView.updateMarkdownToggle(visible: model.usesMarkdownPreview, isRendered: true)
        footerView.configure(
            model: model,
            fileSize: nil,
            browserName: nil,
            defaultAppForFile: nil
        )

        let size = ClipPreviewPopover.fitSize(for: model, maxHeight: maxHeight)
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()

        metadataTask = Task { @MainActor [weak self] in
            await self?.loadMetadata(for: model)
        }

        return size
    }

    func refreshHeader() {
        guard let model else { return }
        headerView.configure(model: model, appIcon: appIcon)
    }

    func cleanup() {
        metadataTask?.cancel()
        metadataTask = nil
        model = nil
        appIcon = nil
        defaultBrowserName = nil
        defaultAppForFile = nil
        fileSize = nil
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
    }

    // MARK: - Actions

    private func bindActions() {
        headerView.onClose = { [weak self] in
            self?.onDismiss?()
        }
        headerView.onShare = { [weak self] sourceView in
            guard let model = self?.model else { return }
            let items = model.shareableItems
            guard !items.isEmpty else { return }
            let picker = NSSharingServicePicker(items: items)
            picker.show(relativeTo: sourceView.bounds, of: sourceView, preferredEdge: .minY)
        }
        headerView.onEdit = { [weak self] in
            guard let model = self?.model else { return }
            self?.onDismiss?()
            EditWindowController.shared.openWindow(with: model)
        }
        headerView.onToggleMarkdown = { [weak self] in
            guard let self else { return }
            let isRendered = contentView.toggleMarkdownMode()
            headerView.setMarkdownRendered(isRendered)
        }
        headerView.onOpenWithApp = { [weak self] in
            guard let path = self?.model?.cachedFilePaths?.first else { return }
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
        headerView.onPinToChip = { [weak self] chipId in
            guard let model = self?.model else { return }
            self?.onPinToChip?(model, chipId)
            self?.headerView.configure(model: model, appIcon: self?.appIcon)
        }
        headerView.onUnpin = { [weak self] in
            guard let model = self?.model else { return }
            self?.onUnpin?(model)
            self?.headerView.configure(model: model, appIcon: self?.appIcon)
        }
        headerView.onCreateChip = { [weak self] in
            guard let model = self?.model else { return }
            self?.onCreateChip?(model)
        }
        footerView.onShowInFinder = { [weak self] in
            guard let path = self?.model?.cachedFilePaths?.first else { return }
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        }
        footerView.onOpenInBrowser = { [weak self] in
            guard let url = self?.model?.attributeString.string.asCompleteURL()
            else { return }
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Metadata Loading

    private func loadMetadata(for model: PasteboardModel) async {
        guard !Task.isCancelled else { return }

        if !model.appPath.isEmpty {
            appIcon = NSWorkspace.shared.icon(forFile: model.appPath)
        }

        defaultBrowserName = bundleDisplayName(
            for: NSWorkspace.shared.urlForApplication(
                toOpen: URL(string: "https://")!
            )
        )

        let isSingleFile = model.type == .file && model.fileSize() == 1
        if isSingleFile, let filePath = model.cachedFilePaths?.first {
            let url = URL(fileURLWithPath: filePath)
            defaultAppForFile = bundleDisplayName(
                for: NSWorkspace.shared.urlForApplication(toOpen: url)
            )
            if let attrs = try? FileManager.default.attributesOfItem(
                atPath: url.path
            ),
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
        return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName")
            as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}
