//
//  CardImageContentView.swift
//  Clipboard
//

import AppKit
import SnapKit
import VisionKit

// MARK: - CardImageContentView

final class CardImageContentView: NSView, PassthroughMouseEvents {
    private lazy var checkerboardView = CheckerboardView()
    private lazy var imageView = CardImageView()

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

    private var loadTask: Task<Void, Never>?
    private var ocrTask: Task<Void, Never>?
    private var ocrRequestId: String?
    private var currentModelId: String = ""
    private var currentKeyword: String = ""
    private var liveTextAnalysis: ImageAnalysis?

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
        if let ocrRequestId {
            log.warn("OCR 高亮请求取消：id=\(ocrRequestId)，原因=卡片释放")
        }
        ocrTask?.cancel()
    }

    func cancelLoad(reason: String) {
        loadTask?.cancel()
        loadTask = nil
        cancelOCR(reason: reason)
    }

    func updateKeyword(_ keyword: String, model: PasteboardModel) {
        currentKeyword = keyword
        if imageView.image != nil {
            updateOCR(model: model, reason: "搜索条件重新配置")
        }
    }

    private func setupViews() {
        addSubview(checkerboardView)
        addSubview(imageView)
        addSubview(loadingIndicator)
        addSubview(placeholderImageView)

        checkerboardView.snp.makeConstraints { $0.edges.equalToSuperview() }
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }

        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        placeholderImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(48)
        }
    }

    private func load(model: PasteboardModel, keyword: String) {
        guard currentModelId != model.uniqueId else {
            updateKeyword(keyword, model: model)
            return
        }

        loadTask?.cancel()
        currentModelId = model.uniqueId
        currentKeyword = keyword
        liveTextAnalysis = nil
        imageView.isHidden = true
        placeholderImageView.isHidden = true
        loadingIndicator.isHidden = false
        loadingIndicator.startAnimation(nil)

        loadTask = Task { @MainActor [weak self] in
            let image = await model.loadThumbnail()
            guard !Task.isCancelled, let self else { return }

            loadingIndicator.stopAnimation(nil)
            loadingIndicator.isHidden = true

            if let image {
                imageView.image = image
                imageView.isHidden = false
            } else {
                placeholderImageView.isHidden = false
            }

            updateOCR(model: model, reason: "缩略图加载完成")
        }
    }

    private func updateOCR(model: PasteboardModel, reason: String) {
        cancelOCR(reason: reason)
        imageView.clearHighlights()

        let trimmed = currentKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, model.type == .image else {
            return
        }

        let requestId = UUID().uuidString
        ocrRequestId = requestId
        let cachedAnalysis = liveTextAnalysis
        ocrTask = Task { @MainActor [weak self] in
            if #available(macOS 27.0, *), LiveTextService.isSupported {
                do {
                    let analysis: ImageAnalysis
                    if let cachedAnalysis {
                        analysis = cachedAnalysis
                    } else {
                        analysis = try await LiveTextService.shared.analyze(data: model.data, requestId: requestId)
                    }
                    guard !Task.isCancelled, let self, ocrRequestId == requestId else { return }
                    liveTextAnalysis = analysis
                    imageView.highlight(analysis, keyword: trimmed)
                } catch {
                    // 失败或取消时不缓存结果，下次搜索重新识别
                }
            } else {
                let regions = await model.loadOCRHighlightRegions(keyword: trimmed, requestId: requestId)
                guard !Task.isCancelled, let self, ocrRequestId == requestId else { return }
                imageView.regions = regions
            }
            guard let self, ocrRequestId == requestId else { return }
            ocrTask = nil
            ocrRequestId = nil
        }
    }

    private func cancelOCR(reason: String) {
        if let ocrRequestId {
            log.warn("OCR 高亮请求取消：id=\(ocrRequestId)，原因=\(reason)")
        }
        ocrTask?.cancel()
        ocrTask = nil
        ocrRequestId = nil
    }
}
