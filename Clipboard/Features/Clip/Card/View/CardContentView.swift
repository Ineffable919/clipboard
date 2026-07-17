//
//  CardContentView.swift
//  Clipboard
//

import AppKit
import Combine
import SnapKit

// MARK: - NSTextView factory

private func makeCardTextView() -> PassthroughTextView {
    let tv = PassthroughTextView(usingTextLayoutManager: false)
    tv.isEditable = false
    tv.isSelectable = false
    tv.drawsBackground = false
    tv.isHorizontallyResizable = false
    tv.isVerticallyResizable = true
    tv.textContainer?.widthTracksTextView = false
    tv.textContainer?.heightTracksTextView = false
    tv.textContainer?.lineFragmentPadding = 0
    tv.textContainer?.lineBreakMode = .byWordWrapping
    tv.textContainer?.containerSize = CGSize(
        width: Const.cardSize - Const.space10 * 2,
        height: .greatestFiniteMagnitude
    )
    tv.textContainerInset = NSSize(width: Const.space10, height: Const.space8)
    tv.layoutManager?.allowsNonContiguousLayout = false
    return tv
}

// MARK: - CardContentView

final class CardContentView: NSView, PassthroughMouseEvents {
    private var currentContentView: NSView?
    private nonisolated(unsafe) var currentModel: PasteboardModel?
    private nonisolated(unsafe) var currentKeyword: String = ""

    private var linkPreviewCancellable: AnyCancellable?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        observeLinkPreviewSetting()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: Configure

    func configure(with model: PasteboardModel, keyword: String = "") {
        let isSameModel = currentModel?.uniqueId == model.uniqueId
        let isSameKeyword = currentKeyword == keyword

        currentModel = model
        currentKeyword = keyword

        guard !isSameModel || !isSameKeyword else { return }

        if isSameModel {
            updateKeyword(keyword, in: currentContentView)
        } else {
            replaceContentView(for: model, keyword: keyword)
        }
    }

    func resetContent() {
        cancelCurrentLoad()
        currentContentView?.removeFromSuperview()
        currentContentView = nil
        currentModel = nil
        currentKeyword = ""
    }

    // MARK: Private

    private func observeLinkPreviewSetting() {
        linkPreviewCancellable = UserDefaults.standard
            .publisher(for: \.enableLinkPreview)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self,
                      let model = currentModel,
                      model.type == .link
                else { return }
                replaceContentView(for: model, keyword: currentKeyword)
            }
    }

    private func replaceContentView(for model: PasteboardModel, keyword: String) {
        cancelCurrentLoad()
        currentContentView?.removeFromSuperview()
        currentContentView = nil

        let view = makeContentView(for: model, keyword: keyword)
        addSubview(view)
        view.snp.makeConstraints { $0.edges.equalToSuperview() }
        currentContentView = view
    }

    private func updateKeyword(_ keyword: String, in view: NSView?) {
        guard let model = currentModel else { return }
        switch view {
        case let v as CardStringContentView:
            v.updateKeyword(keyword, model: model)
        case let v as CardRichContentView:
            v.updateKeyword(keyword, model: model)
        case let v as CardImageContentView:
            v.updateKeyword(keyword, model: model)
        case let v as CardLinkPreviewContentView:
            v.updateKeyword(keyword, model: model)
        default:
            break
        }
    }

    private func cancelCurrentLoad() {
        if let imageView = currentContentView as? CardImageContentView {
            imageView.cancelLoad()
        } else if let linkView = currentContentView as? CardLinkPreviewContentView {
            linkView.cancelLoad()
        } else if let fileView = currentContentView as? CardFileContentView {
            fileView.cancelLoad()
        }
    }

    private func makeContentView(for model: PasteboardModel, keyword: String) -> NSView {
        switch model.type {
        case .color:
            return CardColorContentView(model: model)
        case .image:
            return CardImageContentView(model: model, keyword: keyword)
        case .file:
            return CardFileContentView(model: model)
        case .rich:
            if model.hasBgColor {
                return CardRichContentView(model: model, keyword: keyword)
            } else {
                return CardStringContentView(model: model, keyword: keyword)
            }
        case .link:
            if PasteUserDefaults.enableLinkPreview {
                return CardLinkPreviewContentView(model: model, keyword: keyword)
            }
            return CardStringContentView(model: model, keyword: keyword)
        case .string:
            return CardStringContentView(model: model, keyword: keyword)
        case .none:
            return NSView()
        }
    }
}

// MARK: - CardStringContentView

final class CardStringContentView: NSView, PassthroughMouseEvents {
    private lazy var textView: PassthroughTextView = makeCardTextView()

    init(model: PasteboardModel, keyword: String) {
        super.init(frame: .zero)
        addSubview(textView)
        textView.snp.makeConstraints { $0.edges.equalToSuperview() }

        let attributed: NSAttributedString = keyword.isEmpty
            ? model.plainTextAttributedString
            : model.highlightedNSAttributedString(keyword: keyword)
        textView.textStorage?.setAttributedString(attributed)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func updateKeyword(_ keyword: String, model: PasteboardModel) {
        let attributed: NSAttributedString = keyword.isEmpty
            ? model.plainTextAttributedString
            : model.highlightedNSAttributedString(keyword: keyword)
        textView.textStorage?.setAttributedString(attributed)
    }
}

// MARK: - PassthroughTextView

private final class PassthroughTextView: NSTextView {
    override func mouseDown(with event: NSEvent) {
        isSelectable ? super.mouseDown(with: event) : nextResponder?.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        isSelectable ? super.mouseUp(with: event) : nextResponder?.mouseUp(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        isSelectable ? super.mouseDragged(with: event) : nextResponder?.mouseDragged(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }
}

// MARK: - CardRichContentView

final class CardRichContentView: NSView, PassthroughMouseEvents {
    private lazy var textView: PassthroughTextView = makeCardTextView()

    init(model: PasteboardModel, keyword: String) {
        super.init(frame: .zero)

        if let bgColor = model.safeBgColor {
            textView.drawsBackground = true
            textView.backgroundColor = bgColor
        }

        addSubview(textView)
        textView.snp.makeConstraints { $0.edges.equalToSuperview() }
        textView.textStorage?.setAttributedString(model.highlightedRichText(keyword: keyword))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func updateKeyword(_ keyword: String, model: PasteboardModel) {
        textView.textStorage?.setAttributedString(model.highlightedRichText(keyword: keyword))
    }
}

// MARK: - CardColorContentView

final class CardColorContentView: NSView, PassthroughMouseEvents {
    private lazy var label: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.font = .systemFont(ofSize: NSFont.systemFontSize + 4, weight: .medium)
        field.alignment = .center
        field.lineBreakMode = .byTruncatingTail
        return field
    }()

    private var dynamicBgColor: NSColor = .controlBackgroundColor

    init(model: PasteboardModel) {
        super.init(frame: .zero)
        wantsLayer = true

        dynamicBgColor = model.cachedBackgroundColor ?? .controlBackgroundColor
        applyColors()

        label.stringValue = model.colorDisplayText
        addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(Const.space8)
            make.trailing.lessThanOrEqualToSuperview().offset(-Const.space8)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
    }

    private func applyColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = dynamicBgColor.cgColor
            label.textColor = contrastingNSColor(for: dynamicBgColor)
        }
    }
}

// MARK: - CardFileContentView

final class CardFileContentView: NSView, PassthroughMouseEvents {
    private var thumbnailView: CardFileThumbnailView?
    private var multiView: CardMultipleFilesView?

    init(model: PasteboardModel) {
        super.init(frame: .zero)

        if let filePaths = model.cachedFilePaths, !filePaths.isEmpty {
            if filePaths.count > 1 {
                let mv = CardMultipleFilesView(filePaths: filePaths)
                multiView = mv
                addSubview(mv)
                mv.snp.makeConstraints { $0.edges.equalToSuperview() }
            } else {
                let tv = CardFileThumbnailView(filePath: filePaths[0])
                thumbnailView = tv
                addSubview(tv)
                tv.snp.makeConstraints { make in
                    make.centerX.equalToSuperview()
                    make.centerY.equalToSuperview().offset(-Const.space20)
                }
            }
        } else {
            let placeholder = CardFileIconPlaceholder()
            addSubview(placeholder)
            placeholder.snp.makeConstraints { $0.edges.equalToSuperview() }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func cancelLoad() {
        thumbnailView?.cancelLoad()
        multiView?.cancelLoad()
    }
}

// MARK: - CardFileThumbnailView

final class CardFileThumbnailView: NSView, PassthroughMouseEvents {
    private lazy var imageView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyDown
        return iv
    }()

    private var loadTask: Task<Void, Never>?
    let maxSize: CGFloat

    init(filePath: String, maxSize: CGFloat = 128) {
        self.maxSize = maxSize
        super.init(frame: .zero)

        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.lessThanOrEqualTo(maxSize)
            make.width.height.equalTo(maxSize).priority(.low)
        }

        let fileURL = URL(fileURLWithPath: filePath)
        imageView.image = FileThumbnailService.shared.systemIcon(for: fileURL)

        guard FileManager.default.fileExists(atPath: filePath) else { return }

        loadTask = Task { @MainActor [weak self] in
            let image = await FileThumbnailService.shared.generateThumbnail(for: fileURL)
            guard !Task.isCancelled else { return }
            self?.imageView.image = image
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
    }

    deinit {
        loadTask?.cancel()
    }
}

// MARK: - CardMultipleFilesView

final class CardMultipleFilesView: NSView, PassthroughMouseEvents {
    private var thumbnailViews: [CardFileThumbnailView] = []

    init(filePaths: [String]) {
        super.init(frame: .zero)

        let thumbSize: CGFloat = 64 // 128 * 0.5
        let paths = Array(filePaths.prefix(4))

        for (index, path) in paths.enumerated().reversed() {
            let thumbView = CardFileThumbnailView(filePath: path, maxSize: thumbSize)
            thumbnailViews.append(thumbView)
            addSubview(thumbView)

            let xOffset = CGFloat(index) * 20
            let yOffset = CGFloat(index) * 10

            thumbView.wantsLayer = true
            thumbView.layer?.cornerRadius = Const.radius
            thumbView.layer?.masksToBounds = true

            thumbView.snp.makeConstraints { make in
                make.width.height.equalTo(thumbSize)
                make.centerX.equalToSuperview().offset(xOffset - Const.space32)
                make.centerY.equalToSuperview().offset(-yOffset)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func cancelLoad() {
        thumbnailViews.forEach { $0.cancelLoad() }
    }
}

// MARK: - CardFileIconPlaceholder

private final class CardFileIconPlaceholder: NSView {
    private lazy var imageView: NSImageView = {
        let iv = NSImageView()
        iv.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
        iv.contentTintColor = NSColor.controlAccentColor.withAlphaComponent(0.8)
        iv.imageScaling = .scaleProportionallyUpOrDown
        return iv
    }()

    override init(frame: NSRect) {
        super.init(frame: frame)
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(48)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}

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
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.isHidden = true
        return iv
    }()

    private lazy var loadingIndicator: NSProgressIndicator = {
        let pi = NSProgressIndicator()
        pi.style = .spinning
        pi.controlSize = .small
        pi.isHidden = true
        return pi
    }()

    private lazy var placeholderImageView: NSImageView = {
        let iv = NSImageView()
        iv.image = NSImage(systemSymbolName: "photo.badge.arrow.down", accessibilityDescription: nil)
        iv.contentTintColor = .secondaryLabelColor
        iv.imageScaling = .scaleProportionallyUpOrDown
        return iv
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
        let x = imageLayout.origin.x + normalizedBox.origin.x * imageLayout.width
        let y = imageLayout.origin.y + (1 - normalizedBox.origin.y - normalizedBox.height) * imageLayout.height
        let w = normalizedBox.width * imageLayout.width
        let h = normalizedBox.height * imageLayout.height
        return CGRect(x: x, y: y, width: w, height: h)
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

    let x = (containerSize.width - renderSize.width) / 2
    let y = (containerSize.height - renderSize.height) / 2
    return CGRect(origin: CGPoint(x: x, y: y), size: renderSize)
}

// MARK: - CheckerboardView

final class CheckerboardView: NSView {
    private var cachedTile: CGImage?
    private var cachedAppearanceName: NSAppearance.Name?
    private var lightColor: NSColor = Const.lightImageShallowColor
    private var darkColor: NSColor = Const.lightImageDeepColor

    private static let tileSize: CGFloat = 16 // 2×2 格，每格 8pt

    override init(frame: NSRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let tile = currentTile() else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        ctx.saveGState()
        ctx.clip(to: dirtyRect)
        let tileSize = Self.tileSize
        let origin = bounds.origin
        var y = origin.y
        while y < dirtyRect.maxY {
            var x = origin.x
            while x < dirtyRect.maxX {
                ctx.draw(tile, in: CGRect(x: x, y: y, width: tileSize, height: tileSize))
                x += tileSize
            }
            y += tileSize
        }
        ctx.restoreGState()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        cachedAppearanceName = nil
        cachedTile = nil
        needsDisplay = true
    }

    // MARK: Private

    private func currentTile() -> CGImage? {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let name: NSAppearance.Name = isDark ? .darkAqua : .aqua
        if cachedAppearanceName == name, let tile = cachedTile {
            return tile
        }

        cachedAppearanceName = name
        lightColor = isDark ? Const.darkImageShallowColor : Const.lightImageShallowColor
        darkColor = isDark ? Const.darkImageDeepColor : Const.lightImageDeepColor
        cachedTile = renderTile()
        return cachedTile
    }

    private func renderTile() -> CGImage? {
        let size = Int(Self.tileSize)
        let half = size / 2
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: size, height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setFillColor(lightColor.cgColor)
        ctx.fill([CGRect(x: 0, y: 0, width: half, height: half),
                  CGRect(x: half, y: half, width: half, height: half)])

        ctx.setFillColor(darkColor.cgColor)
        ctx.fill([CGRect(x: half, y: 0, width: half, height: half),
                  CGRect(x: 0, y: half, width: half, height: half)])

        return ctx.makeImage()
    }
}
