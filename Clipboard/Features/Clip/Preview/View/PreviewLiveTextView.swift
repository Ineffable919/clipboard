//
//  PreviewLiveTextView.swift
//  Clipboard
//
//  Created by crown on 2026/8/26
//
//  图片实况文本分析与交互覆盖层
//

import AppKit
import SnapKit
import VisionKit

final class PreviewLiveTextView: NSView, ImageAnalysisOverlayViewDelegate, PreviewResettable {
    @MainActor private static var activeAnalysisTask: Task<Void, Never>?
    @MainActor private static var activeAnalysisGeneration = 0

    private let imageView: NSImageView = {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        return imageView
    }()

    private let overlayView = ImageAnalysisOverlayView()
    private var analysisTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?

    private static let analysisDelay: Duration = .milliseconds(400)

    private static let sharedAnalyzer: ImageAnalyzer? = {
        guard ImageAnalyzer.isSupported else { return nil }
        return ImageAnalyzer()
    }()

    /// maxPixelSize 按显示尺寸降采样，解码结果走缩略图缓存，连续开关预览不再重复解码原图
    init(model: PasteboardModel, maxPixelSize: Int) {
        super.init(frame: .zero)
        setupViews()
        let id = model.uniqueId
        let data = model.data
        loadTask = Task { @MainActor [weak self] in
            let image = await ImageThumbnailCache.shared.image(
                for: id, data: data, maxPixelSize: maxPixelSize
            )
            guard let self, !Task.isCancelled else { return }
            showImage(image)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit {
        loadTask?.cancel()
        analysisTask?.cancel()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            cancelAnalysis()
        } else {
            scheduleAnalysisIfNeeded()
        }
    }

    func resetPreview() {
        loadTask?.cancel()
        loadTask = nil
        cancelAnalysis()
        overlayView.analysis = nil
        overlayView.trackingImageView = nil
        overlayView.delegate = nil
        imageView.image = nil
    }

    override func layout() {
        super.layout()
        overlayView.setContentsRectNeedsUpdate()
    }

    func contentsRect(for _: ImageAnalysisOverlayView) -> CGRect {
        guard let image = imageView.image,
              bounds.width > 0, bounds.height > 0
        else { return CGRect(x: 0, y: 0, width: 1, height: 1) }

        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        let viewSize = bounds.size
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        let renderedWidth: CGFloat
        let renderedHeight: CGFloat

        if imageAspect > viewAspect {
            renderedWidth = viewSize.width
            renderedHeight = viewSize.width / imageAspect
        } else {
            renderedHeight = viewSize.height
            renderedWidth = viewSize.height * imageAspect
        }

        return CGRect(
            x: (viewSize.width - renderedWidth) / 2 / viewSize.width,
            y: (viewSize.height - renderedHeight) / 2 / viewSize.height,
            width: renderedWidth / viewSize.width,
            height: renderedHeight / viewSize.height
        )
    }

    private func setupViews() {
        addSubview(imageView)
        overlayView.delegate = self
        overlayView.preferredInteractionTypes = .automatic
        addSubview(overlayView)

        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }
        overlayView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func showImage(_ cgImage: CGImage?) {
        if let cgImage {
            imageView.image = NSImage(cgImage: cgImage, size: .zero)
            overlayView.setContentsRectNeedsUpdate()
            scheduleAnalysisIfNeeded()
        } else {
            let configuration = NSImage.SymbolConfiguration(pointSize: 64, weight: .regular)
            imageView.image = NSImage(
                systemSymbolName: "photo.badge.arrow.down",
                accessibilityDescription: nil
            )?.withSymbolConfiguration(configuration)
            imageView.imageScaling = .scaleNone
            imageView.contentTintColor = .secondaryLabelColor
        }
    }

    private func cancelAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
    }

    private func scheduleAnalysisIfNeeded() {
        guard window != nil,
              imageView.image != nil,
              overlayView.analysis == nil,
              Self.sharedAnalyzer != nil
        else { return }

        analysisTask?.cancel()
        analysisTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.analysisDelay)
            } catch {
                return
            }

            guard let self,
                  !Task.isCancelled,
                  window != nil,
                  let image = imageView.image
            else { return }

            let previous = Self.activeAnalysisTask
            previous?.cancel()
            Self.activeAnalysisGeneration += 1
            let generation = Self.activeAnalysisGeneration
            Self.activeAnalysisTask = analysisTask
            // 取消不一定能撤回 VisionKit 已排队的请求，等上一个请求结束再提交，队列里最多一个
            await previous?.value
            guard !Task.isCancelled, window != nil else { return }
            await analyzeImage(image)
            if Self.activeAnalysisGeneration == generation {
                Self.activeAnalysisTask = nil
            }
        }
    }

    private func analyzeImage(_ image: NSImage) async {
        guard let analyzer = Self.sharedAnalyzer,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              !Task.isCancelled
        else { return }

        let configuration = ImageAnalyzer.Configuration([.text, .machineReadableCode])
        do {
            let analysis = try await analyzer.analyze(
                cgImage,
                orientation: .up,
                configuration: configuration
            )
            guard !Task.isCancelled, window != nil else { return }
            overlayView.analysis = analysis
            overlayView.trackingImageView = imageView
            overlayView.setContentsRectNeedsUpdate()
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            log.warn("Live Text analysis failed: \(error)")
        }
    }
}
