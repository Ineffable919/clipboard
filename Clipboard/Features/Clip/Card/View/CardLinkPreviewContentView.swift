//
//  CardLinkPreviewContentView.swift
//  Clipboard
//
//  AppKit re-implementation of the SwiftUI LinkPreviewCardView.
//  Fetches link metadata via LPMetadataProvider and caches the result on the model.
//

import AppKit
@preconcurrency import LinkPresentation
import SnapKit

// MARK: - CardLinkPreviewContentView

final class CardLinkPreviewContentView: NSView, PassthroughMouseEvents {
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
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.isHidden = true
        return iv
    }()

    private lazy var placeholderImageView: NSImageView = {
        let iv = NSImageView()
        iv.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
        iv.contentTintColor = .secondaryLabelColor
        iv.imageScaling = .scaleProportionallyUpOrDown
        return iv
    }()

    private lazy var infoView: DynamicBackgroundView = {
        let v = DynamicBackgroundView()
        v.wantsLayer = true
        return v
    }()

    private lazy var titleLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        f.textColor = .labelColor
        f.lineBreakMode = .byTruncatingTail
        f.maximumNumberOfLines = 1
        return f
    }()

    private lazy var urlLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        f.textColor = .secondaryLabelColor
        f.lineBreakMode = .byTruncatingTail
        f.maximumNumberOfLines = 1
        f.allowsEditingTextAttributes = false
        return f
    }()

    // MARK: - State

    private var fetchTask: Task<Void, Never>?

    private var fetchedModelId: String = ""

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
            ?? url?.host()
            ?? urlString

        urlLabel.attributedStringValue = makeURLAttributedString(
            urlString: urlString,
            keyword: keyword
        )

        if let meta = model.cachedLinkMetadata {
            applyMetadata(meta)
            return
        }

        resetImageViews()

        guard let url else {
            fetchedModelId = ""
            return
        }

        guard fetchedModelId != model.uniqueId else { return }
        fetchedModelId = model.uniqueId

        fetchTask?.cancel()

        fetchTask = Task.detached(priority: .userInitiated) { [weak self, weak model] in
            guard let self, let model else { return }

            let meta = await Self.fetchMetadata(for: url)

            await MainActor.run {
                guard !Task.isCancelled else { return }
                model.cachedLinkMetadata = meta
                self.titleLabel.stringValue = meta.title ?? url.host() ?? url.absoluteString
                self.applyMetadata(meta)
            }
        }
    }

    func cancelLoad() {
        fetchTask?.cancel()
        fetchTask = nil
        fetchedModelId = ""
    }

    func updateKeyword(_ keyword: String, model: PasteboardModel) {
        configure(with: model, keyword: keyword)
    }

    // MARK: - Appearance

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackground()
    }

    // MARK: - Private: Layout

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

    // MARK: - Private: Image state

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

    // MARK: - Private: URL label

    private func makeURLAttributedString(
        urlString: String,
        keyword: String
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraphStyle,
        ]

        let mutable = NSMutableAttributedString(string: urlString, attributes: baseAttrs)

        guard !keyword.isEmpty else {
            return mutable
        }

        let plain = urlString as NSString
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

        return mutable
    }

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

            let previewImage: NSImage? = await loadImage(from: metadata.imageProvider)
            let iconImage: NSImage? = previewImage == nil
                ? await loadImage(from: metadata.iconProvider)
                : nil

            return LinkPreviewMetadata(
                title: metadata.title,
                previewImage: previewImage,
                iconImage: iconImage
            )
        } catch {
            return LinkPreviewMetadata(title: nil, previewImage: nil, iconImage: nil)
        }
    }

    private static func loadImage(from provider: NSItemProvider?) async -> NSImage? {
        guard let provider else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: NSImage.self) { image, _ in
                continuation.resume(returning: image as? NSImage)
            }
        }
    }
}
