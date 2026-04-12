//
//  CardContentView.swift
//  Clipboard
//
//  AppKit re-implementation of the SwiftUI CardContentView.
//  Dispatches to a type-specific sub-view based on PasteModelType.
//
//  Created by crown on 2026/4/9.
//

import AppKit
import SnapKit

// MARK: - CardContentView

final class CardContentView: NSView {
    private var currentContentView: NSView?
    private nonisolated(unsafe) var currentModel: PasteboardModel?
    private nonisolated(unsafe) var currentKeyword: String = ""
    private nonisolated(unsafe) var previewObserverToken: Any?

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

    deinit {
        if let token = previewObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
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

    // MARK: Private

    private func observeLinkPreviewSetting() {
        previewObserverToken = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self,
                      let model = self.currentModel,
                      model.type == .link
                else { return }
                self.replaceContentView(for: model, keyword: self.currentKeyword)
            }
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
            return CardRichContentView(model: model, keyword: keyword)
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

final class CardStringContentView: NSView {
    private lazy var textView: PassthroughTextView = {
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
    }()

    init(model: PasteboardModel, keyword: String) {
        super.init(frame: .zero)
        addSubview(textView)
        textView.snp.makeConstraints { $0.edges.equalToSuperview() }

        let attributed: NSAttributedString = keyword.isEmpty
            ? model.attributeString
            : model.highlightedNSAttributedString(keyword: keyword)
        textView.textStorage?.setAttributedString(attributed)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func updateKeyword(_ keyword: String, model: PasteboardModel) {
        let attributed: NSAttributedString = keyword.isEmpty
            ? model.attributeString
            : model.highlightedNSAttributedString(keyword: keyword)
        textView.textStorage?.setAttributedString(attributed)
    }

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

final class CardRichContentView: NSView {
    private lazy var textView: PassthroughTextView = {
        let tv = PassthroughTextView(usingTextLayoutManager: false)
        tv.isEditable = false
        tv.isSelectable = false
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
    }()

    init(model: PasteboardModel, keyword: String) {
        super.init(frame: .zero)

        if model.hasBgColor, let bgColor = model.nsBackgroundColor {
            textView.drawsBackground = true
            textView.backgroundColor = bgColor
        } else {
            textView.drawsBackground = false
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
}

// MARK: - CardColorContentView

final class CardColorContentView: NSView {
    private lazy var label: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.font = .systemFont(ofSize: 17, weight: .medium)
        field.alignment = .center
        field.lineBreakMode = .byTruncatingTail
        return field
    }()

    init(model: PasteboardModel) {
        super.init(frame: .zero)
        wantsLayer = true

        let bgNS = model.nsBackgroundColor ?? NSColor.controlBackgroundColor
        layer?.backgroundColor = bgNS.cgColor

        let textNS = contrastingNSColor(for: bgNS)
        label.stringValue = model.colorDisplayText
        label.textColor = textNS

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
}

// MARK: - CardFileContentView

final class CardFileContentView: NSView {
    init(model: PasteboardModel) {
        super.init(frame: .zero)

        if let filePaths = model.cachedFilePaths, !filePaths.isEmpty {
            if filePaths.count > 1 {
                let multiView = CardMultipleFilesView(filePaths: filePaths)
                addSubview(multiView)
                multiView.snp.makeConstraints { $0.edges.equalToSuperview() }
            } else {
                let thumbView = CardFileThumbnailView(filePath: filePaths[0])
                addSubview(thumbView)
                thumbView.snp.makeConstraints { make in
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
}

// MARK: - CardFileThumbnailView

final class CardFileThumbnailView: NSView {
    private lazy var imageView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyDown // scaledToFit
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
}

// MARK: - CardMultipleFilesView

final class CardMultipleFilesView: NSView {
    private var thumbnailViews: [CardFileThumbnailView] = []

    init(filePaths: [String]) {
        super.init(frame: .zero)

        let maxSize: CGFloat = 128
        let thumbSize = maxSize * 0.5

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
                make.centerY.equalToSuperview().offset(-yOffset + Const.space32)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    /// Pass mouse events through
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

final class CardImageContentView: NSView {
    private lazy var checkerboardView = CheckerboardView()

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
    /// true = fill (aspect-fill, clipped), false = fit (aspect-fit)
    private var isFillMode: Bool = false
    private var currentImageSize: CGSize?

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

    private func setupViews() {
        addSubview(checkerboardView)
        addSubview(imageView)
        addSubview(ocrOverlayView)
        addSubview(loadingIndicator)
        addSubview(placeholderImageView)

        checkerboardView.snp.makeConstraints { $0.edges.equalToSuperview() }
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

        imageView.snp.remakeConstraints { make in
            make.center.equalToSuperview()
            if isFillMode {
                if imageRatio > containerRatio {
                    make.height.equalToSuperview()
                    make.width.equalTo(imageView.snp.height).multipliedBy(imageRatio)
                } else {
                    make.width.equalToSuperview()
                    make.height.equalTo(imageView.snp.width).dividedBy(imageRatio)
                }
            } else {
                make.edges.equalToSuperview()
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
                let imageRatio = image.size.width / image.size.height
                let ratioDiff = abs(imageRatio - Self.containerRatio)
                isFillMode = ratioDiff < 0.5
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
        let imageRatio = imageSize.width / imageSize.height
        let containerRatio = containerSize.width / containerSize.height

        let renderSize: CGSize
        if isFillMode {
            if imageRatio > containerRatio {
                let h = containerSize.height
                renderSize = CGSize(width: h * imageRatio, height: h)
            } else {
                let w = containerSize.width
                renderSize = CGSize(width: w, height: w / imageRatio)
            }
        } else {
            if imageRatio > containerRatio {
                let w = containerSize.width
                renderSize = CGSize(width: w, height: w / imageRatio)
            } else {
                let h = containerSize.height
                renderSize = CGSize(width: h * imageRatio, height: h)
            }
        }

        let x = (containerSize.width - renderSize.width) / 2
        let y = (containerSize.height - renderSize.height) / 2
        return CGRect(origin: CGPoint(x: x, y: y), size: renderSize)
    }

    private func convertToContainerRect(normalizedBox: CGRect, imageLayout: CGRect) -> CGRect {
        let x = imageLayout.origin.x + normalizedBox.origin.x * imageLayout.width
        let y = imageLayout.origin.y + (1 - normalizedBox.origin.y - normalizedBox.height) * imageLayout.height
        let w = normalizedBox.width * imageLayout.width
        let h = normalizedBox.height * imageLayout.height
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

// MARK: - CheckerboardView

final class CheckerboardView: NSView {
    private var cachedAppearanceName: NSAppearance.Name?
    private var lightColor: NSColor = Const.lightImageShallowColor
    private var darkColor: NSColor = Const.lightImageDeepColor

    override init(frame: NSRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func draw(_ dirtyRect: NSRect) {
        refreshColorsIfNeeded()

        let sq: CGFloat = 8
        let minX = floor(dirtyRect.minX / sq) * sq
        let minY = floor(dirtyRect.minY / sq) * sq
        let maxX = dirtyRect.maxX
        let maxY = dirtyRect.maxY

        var y = minY
        while y < maxY {
            var x = minX
            while x < maxX {
                let col = Int(x / sq)
                let row = Int(y / sq)
                let isLight = (col + row) % 2 == 0
                (isLight ? lightColor : darkColor).setFill()
                NSRect(x: x, y: y, width: sq, height: sq).fill()
                x += sq
            }
            y += sq
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        cachedAppearanceName = nil
        needsDisplay = true
    }

    private func refreshColorsIfNeeded() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let name: NSAppearance.Name = isDark ? .darkAqua : .aqua
        guard cachedAppearanceName != name else { return }
        cachedAppearanceName = name
        lightColor = isDark ? Const.darkImageShallowColor : Const.lightImageShallowColor
        darkColor = isDark ? Const.darkImageDeepColor : Const.lightImageDeepColor
    }
}
