//
//  CardLinkPreviewContentView.swift
//  Clipboard
//

import AppKit
import SnapKit

// MARK: - CardLinkPreviewContentView

final class CardLinkPreviewContentView: NSView, PassthroughMouseEvents {
    // MARK: - Subviews

    private lazy var imageContainerView: DynamicBackgroundView = {
        let view = DynamicBackgroundView()
        view.wantsLayer = true
        return view
    }()

    private lazy var previewImageView: NSImageView = {
        let image = NSImageView()
        image.imageScaling = .scaleProportionallyUpOrDown
        image.isHidden = true
        return image
    }()

    private lazy var iconImageView: NSImageView = {
        let image = NSImageView()
        image.imageScaling = .scaleProportionallyUpOrDown
        image.isHidden = true
        return image
    }()

    private lazy var placeholderImageView: NSImageView = {
        let image = NSImageView()
        image.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
        image.contentTintColor = .secondaryLabelColor
        image.imageScaling = .scaleProportionallyUpOrDown
        return image
    }()

    private lazy var infoView: DynamicBackgroundView = {
        let view = DynamicBackgroundView()
        view.wantsLayer = true
        return view
    }()

    private lazy var titleLabel: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        field.textColor = .labelColor
        field.lineBreakMode = .byTruncatingTail
        field.maximumNumberOfLines = 1
        return field
    }()

    private lazy var urlLabel: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        field.textColor = .secondaryLabelColor
        field.lineBreakMode = .byTruncatingMiddle
        field.maximumNumberOfLines = 1
        field.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.truncatesLastVisibleLine = true
        field.allowsEditingTextAttributes = false
        return field
    }()

    // MARK: - State

    private lazy var previewRequest = LinkPreviewRequest(view: self)

    private var requestedModelID = ""

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

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        previewRequest.viewDidMoveToWindow()
    }

    override func viewWillDraw() {
        super.viewWillDraw()
        previewRequest.updateVisibility()
    }

    // MARK: - Public

    func configure(with model: PasteboardModel, keyword: String) {
        let urlString = model.attributeString.string
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let url = urlString.asCompleteURL()

        urlLabel.attributedStringValue = makeURLAttributedString(
            urlString: urlString,
            keyword: keyword
        )

        guard requestedModelID != model.uniqueId else { return }
        cancelLoad()
        titleLabel.stringValue = url?.host() ?? urlString
        resetImageViews()

        guard let url else { return }
        requestedModelID = model.uniqueId

        previewRequest.load { [weak self] in
            let metadata = await LinkPreviewLoader.fetch(for: url, imagePolicy: .previewThenIcon)

            guard !Task.isCancelled, let self else { return }
            applyMetadata(metadata, url: url)
        }
    }

    func cancelLoad() {
        previewRequest.cancel()
        requestedModelID = ""
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
            make.bottom.lessThanOrEqualToSuperview().inset(Const.space4)
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

    private func applyMetadata(_ metadata: LinkPreviewMetadata, url: URL) {
        titleLabel.stringValue = Self.singleLineTitle(metadata.title) ?? url.host() ?? url.absoluteString
        if let image = metadata.previewImage {
            previewImageView.image = image
            previewImageView.imageScaling = .scaleProportionallyUpOrDown
            previewImageView.isHidden = false
            iconImageView.isHidden = true
            placeholderImageView.isHidden = true
        } else if let icon = metadata.iconImage {
            iconImageView.image = icon
            iconImageView.isHidden = false
            previewImageView.isHidden = true
            placeholderImageView.isHidden = true
        } else {
            resetImageViews()
        }
    }

    // MARK: - Private: URL label

    private static func singleLineTitle(_ title: String?) -> String? {
        guard let title else { return nil }
        let normalized = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacing(/\s+/, with: " ")
        return normalized.isEmpty || normalized == "/" ? nil : normalized
    }

    private func makeURLAttributedString(
        urlString: String,
        keyword: String
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingMiddle
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraphStyle
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
}
