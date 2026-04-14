//
//  CardLinkPreviewContentView.swift
//  Clipboard
//
//  AppKit re-implementation of the SwiftUI LinkPreviewCardView.
//  Fetches link metadata via LPMetadataProvider and caches the result on the model.
//

import AppKit
import LinkPresentation
import SnapKit

// MARK: - CardLinkPreviewContentView

final class CardLinkPreviewContentView: NSView {
    // MARK: - Subviews

    private lazy var imageContainerView: DynamicBackgroundView = {
        let v = DynamicBackgroundView()
        v.wantsLayer = true
        return v
    }()

    private lazy var previewImageView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.isHidden = true
        return iv
    }()

    private lazy var iconImageView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyDown
        iv.isHidden = true
        return iv
    }()

    private lazy var placeholderImageView: NSImageView = {
        let iv = NSImageView()
        iv.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
        iv.contentTintColor = .secondaryLabelColor
        iv.imageScaling = .scaleProportionallyDown
        return iv
    }()

    private lazy var infoView: DynamicBackgroundView = {
        let v = DynamicBackgroundView()
        v.wantsLayer = true
        return v
    }()

    private lazy var titleLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = .systemFont(ofSize: 13, weight: .semibold)
        f.textColor = .labelColor
        f.lineBreakMode = .byTruncatingTail
        f.maximumNumberOfLines = 1
        return f
    }()

    private lazy var urlLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = .systemFont(ofSize: 11)
        f.textColor = .secondaryLabelColor
        f.lineBreakMode = .byTruncatingTail
        f.maximumNumberOfLines = 1
        f.allowsEditingTextAttributes = false
        return f
    }()

    // MARK: - State

    private var fetchTask: Task<Void, Never>?
    private var currentModelId: String = ""

    // MARK: - Init

    init(model: PasteboardModel, keyword: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        setupViews()
        configure(with: model, keyword: keyword)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Public

    func configure(with model: PasteboardModel, keyword: String) {
        let urlString = model.attributeString.string
        let url = urlString.asCompleteURL()

        titleLabel.stringValue = model.cachedLinkMetadata?.title
            ?? url?.host() ?? urlString

        if keyword.isEmpty {
            urlLabel.attributedStringValue = NSAttributedString(
                string: url?.absoluteString ?? urlString,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]
            )
        } else {
            let highlighted = model.highlightedPlainText(keyword: keyword)
            let mutable = NSMutableAttributedString(attributedString: highlighted)
            mutable.addAttributes(
                [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ],
                range: NSRange(location: 0, length: mutable.length)
            )
            let plain = highlighted.string as NSString
            let options: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
            var searchRange = NSRange(location: 0, length: plain.length)
            while searchRange.length > 0 {
                let found = plain.range(of: keyword, options: options, range: searchRange, locale: .current)
                guard found.location != NSNotFound else { break }
                mutable.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.65), range: found)
                let next = found.location + found.length
                guard next < plain.length else { break }
                searchRange = NSRange(location: next, length: plain.length - next)
            }
            urlLabel.attributedStringValue = mutable
        }

        if let meta = model.cachedLinkMetadata {
            applyMetadata(meta)
            return
        }

        resetImageViews()

        guard let url, currentModelId != model.uniqueId else { return }
        currentModelId = model.uniqueId

        fetchTask?.cancel()
        fetchTask = Task { @MainActor [weak self, weak model] in
            guard let self, let model else { return }
            let meta = await Self.fetchMetadata(for: url)
            guard !Task.isCancelled else { return }
            model.cachedLinkMetadata = meta
            titleLabel.stringValue = meta.title ?? url.host() ?? url.absoluteString
            applyMetadata(meta)
        }
    }

    func cancelLoad() {
        fetchTask?.cancel()
        fetchTask = nil
    }

    func updateKeyword(_ keyword: String, model: PasteboardModel) {
        configure(with: model, keyword: keyword)
    }

    // MARK: - Mouse passthrough

    override func mouseDown(with event: NSEvent) {
        nextResponder?.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        nextResponder?.mouseUp(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        nextResponder?.mouseDragged(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }

    // MARK: - Appearance

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackground()
    }

    // MARK: - Private layout

    private func setupViews() {
        addSubview(imageContainerView)
        addSubview(infoView)

        imageContainerView.addSubview(previewImageView)
        imageContainerView.addSubview(iconImageView)
        imageContainerView.addSubview(placeholderImageView)

        infoView.addSubview(titleLabel)
        infoView.addSubview(urlLabel)

        infoView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(48)
        }

        imageContainerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(infoView.snp.top)
        }

        previewImageView.snp.makeConstraints { $0.edges.equalToSuperview() }

        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(42)
        }

        placeholderImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(42)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Const.space8)
            make.leading.trailing.equalToSuperview().inset(Const.space8)
        }

        urlLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Const.space4)
            make.leading.trailing.equalToSuperview().inset(Const.space8)
        }

        updateBackground()
    }

    private func updateBackground() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let imageBg: NSColor = isDark ? NSColor(hex: "#272835") : NSColor(hex: "#f5f5f5")
        imageContainerView.dynamicBackgroundColor = imageBg
        infoView.dynamicBackgroundColor = .textBackgroundColor
    }

    private func resetImageViews() {
        previewImageView.isHidden = true
        iconImageView.isHidden = true
        placeholderImageView.isHidden = false
    }

    private func applyMetadata(_ meta: LinkPreviewMetadata) {
        if let img = meta.previewImage {
            previewImageView.image = img
            previewImageView.imageScaling = .scaleProportionallyUpOrDown
            previewImageView.isHidden = false
            iconImageView.isHidden = true
            placeholderImageView.isHidden = true
        } else if let icon = meta.iconImage {
            iconImageView.image = icon
            iconImageView.isHidden = false
            previewImageView.isHidden = true
            placeholderImageView.isHidden = true
        } else {
            resetImageViews()
        }
    }

    // MARK: - Metadata fetch

    private static func fetchMetadata(for url: URL) async -> LinkPreviewMetadata {
        let provider = LPMetadataProvider()
        provider.timeout = 5.0
        do {
            let metadata = try await provider.startFetchingMetadata(for: url)
            guard !Task.isCancelled else {
                provider.cancel()
                return LinkPreviewMetadata(title: nil, previewImage: nil, iconImage: nil)
            }
            var previewImage: NSImage?
            var iconImage: NSImage?
            if let imageProvider = metadata.imageProvider {
                previewImage = await loadImage(from: imageProvider)
            }
            if previewImage == nil, let iconProvider = metadata.iconProvider {
                iconImage = await loadImage(from: iconProvider)
            }
            return LinkPreviewMetadata(title: metadata.title, previewImage: previewImage, iconImage: iconImage)
        } catch {
            return LinkPreviewMetadata(title: nil, previewImage: nil, iconImage: nil)
        }
    }

    private static func loadImage(from provider: NSItemProvider) async -> NSImage? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: NSImage.self) { image, _ in
                continuation.resume(returning: image as? NSImage)
            }
        }
    }
}
