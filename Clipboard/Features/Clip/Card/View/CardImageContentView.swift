//
//  CardImageContentView.swift
//  Clipboard
//

import AppKit
import SnapKit

// MARK: - CardImageContentView

final class CardImageContentView: NSView, PassthroughMouseEvents {
    private lazy var checkerboardView = CheckerboardView()
    private lazy var imageContainerView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        return view
    }()

    private lazy var imageView: NSImageView = {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.isHidden = true
        return view
    }()

    private lazy var loadingIndicator: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.isHidden = true
        return indicator
    }()

    private lazy var placeholderImageView: NSImageView = {
        let view = NSImageView()
        view.image = NSImage(systemSymbolName: "photo.badge.arrow.down", accessibilityDescription: nil)
        view.contentTintColor = .secondaryLabelColor
        view.imageScaling = .scaleProportionallyUpOrDown
        return view
    }()

    private lazy var ocrOverlayView = OCRHighlightOverlayView()

    private var loadTask: Task<Void, Never>?
    private var ocrTask: Task<Void, Never>?
    private var currentModelId: String = ""
    private var currentKeyword: String = ""
    private var isFillMode: Bool = false
    private var currentImageSize: CGSize?

    private let maxFillCropRatio: CGFloat = 0.15

    private static let containerSize = CGSize(width: Const.cardSize, height: Const.cntSize)
    private static let containerRatio = Const.cardSize / Const.cntSize

    init(model: PasteboardModel, keyword: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        setupViews()
        load(model: model, keyword: keyword)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit {
        loadTask?.cancel()
        ocrTask?.cancel()
    }

    func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
        ocrTask?.cancel()
        ocrTask = nil
    }

    func updateKeyword(_ keyword: String, model: PasteboardModel) {
        currentKeyword = ""
        updateOCR(model: model, keyword: keyword)
    }

    private func setupViews() {
        addSubview(checkerboardView)
        addSubview(imageContainerView)
        addSubview(loadingIndicator)
        addSubview(placeholderImageView)

        imageContainerView.addSubview(imageView)
        imageContainerView.addSubview(ocrOverlayView)

        checkerboardView.snp.makeConstraints { $0.edges.equalToSuperview() }
        imageContainerView.snp.makeConstraints { $0.edges.equalToSuperview() }
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }
        ocrOverlayView.snp.makeConstraints { $0.edges.equalToSuperview() }

        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        placeholderImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(48)
        }
    }

    private func applyImageLayout(imageSize: CGSize) {
        let containerSize = Self.containerSize
        let imageRatio = imageSize.width / imageSize.height
        let containerRatio = containerSize.width / containerSize.height

        imageContainerView.snp.remakeConstraints { make in
            make.center.equalToSuperview()
            if isFillMode {
                if imageRatio > containerRatio {
                    make.height.equalToSuperview()
                    make.width.equalTo(imageContainerView.snp.height).multipliedBy(imageRatio)
                } else {
                    make.width.equalToSuperview()
                    make.height.equalTo(imageContainerView.snp.width).dividedBy(imageRatio)
                }
            } else {
                if imageRatio > containerRatio {
                    make.width.equalToSuperview()
                    make.height.equalTo(imageContainerView.snp.width).dividedBy(imageRatio)
                } else {
                    make.height.equalToSuperview()
                    make.width.equalTo(imageContainerView.snp.height).multipliedBy(imageRatio)
                }
            }
        }
    }

    private func load(model: PasteboardModel, keyword: String) {
        guard currentModelId != model.uniqueId else {
            updateOCR(model: model, keyword: keyword)
            return
        }

        loadTask?.cancel()
        currentModelId = model.uniqueId
        imageView.isHidden = true
        placeholderImageView.isHidden = true
        loadingIndicator.isHidden = false
        loadingIndicator.startAnimation(nil)

        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let image = await model.loadThumbnail()
            guard !Task.isCancelled else { return }

            loadingIndicator.stopAnimation(nil)
            loadingIndicator.isHidden = true

            if let image {
                isFillMode = shouldUseFillMode(for: image.size)
                currentImageSize = image.size

                imageView.imageScaling = .scaleProportionallyUpOrDown
                imageView.image = image
                imageView.isHidden = false
                applyImageLayout(imageSize: image.size)
            } else {
                placeholderImageView.isHidden = false
            }

            updateOCR(model: model, keyword: keyword)
        }
    }

    private func updateOCR(model: PasteboardModel, keyword: String) {
        guard currentKeyword != keyword else { return }
        currentKeyword = keyword
        ocrTask?.cancel()

        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, model.type == .image else {
            ocrOverlayView.regions = []
            ocrOverlayView.imageSize = nil
            return
        }

        ocrTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let regions = await model.loadOCRHighlightRegions(keyword: trimmed)
            guard !Task.isCancelled else { return }
            ocrOverlayView.regions = regions
            ocrOverlayView.imageSize = model.cachedImageSize
            ocrOverlayView.isFillMode = isFillMode
            ocrOverlayView.setNeedsDisplay(ocrOverlayView.bounds)
        }
    }

    private func shouldUseFillMode(for imageSize: CGSize) -> Bool {
        guard imageSize.width > 0, imageSize.height > 0 else { return false }

        let fillLayout = imageLayout(
            imageSize: imageSize,
            containerSize: Self.containerSize,
            isFillMode: true
        )
        let fillArea = fillLayout.width * fillLayout.height
        let visibleArea = Self.containerSize.width * Self.containerSize.height

        guard fillArea > 0 else { return false }

        let cropRatio = max(0, 1 - (visibleArea / fillArea))
        return cropRatio <= maxFillCropRatio
    }
}

// MARK: - OCRHighlightOverlayView

private final class OCRHighlightOverlayView: NSView {
    var regions: [OCRTextRegion] = [] {
        didSet { needsDisplay = true }
    }

    var imageSize: CGSize?
    var isFillMode: Bool = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_: NSRect) {
        guard !regions.isEmpty, let imageSize else { return }

        let containerSize = bounds.size
        let layout = computeImageLayout(imageSize: imageSize, containerSize: containerSize)
        NSColor.systemYellow.withAlphaComponent(0.45).setFill()

        for region in regions {
            let rect = convertToContainerRect(normalizedBox: region.boundingBox, imageLayout: layout)
            let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
            path.fill()
        }
    }

    private func computeImageLayout(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        imageLayout(imageSize: imageSize, containerSize: containerSize, isFillMode: isFillMode)
    }

    private func convertToContainerRect(normalizedBox: CGRect, imageLayout: CGRect) -> CGRect {
        let left = imageLayout.origin.x + normalizedBox.origin.x * imageLayout.width
        let top = imageLayout.origin.y + (1 - normalizedBox.origin.y - normalizedBox.height) * imageLayout.height
        let width = normalizedBox.width * imageLayout.width
        let height = normalizedBox.height * imageLayout.height
        return CGRect(x: left, y: top, width: width, height: height)
    }
}

private func imageLayout(imageSize: CGSize, containerSize: CGSize, isFillMode: Bool) -> CGRect {
    let imageRatio = imageSize.width / imageSize.height
    let containerRatio = containerSize.width / containerSize.height

    let renderSize: CGSize
    if isFillMode {
        if imageRatio > containerRatio {
            let height = containerSize.height
            renderSize = CGSize(width: height * imageRatio, height: height)
        } else {
            let width = containerSize.width
            renderSize = CGSize(width: width, height: width / imageRatio)
        }
    } else {
        if imageRatio > containerRatio {
            let width = containerSize.width
            renderSize = CGSize(width: width, height: width / imageRatio)
        } else {
            let height = containerSize.height
            renderSize = CGSize(width: height * imageRatio, height: height)
        }
    }

    let left = (containerSize.width - renderSize.width) / 2
    let top = (containerSize.height - renderSize.height) / 2
    return CGRect(origin: CGPoint(x: left, y: top), size: renderSize)
}
