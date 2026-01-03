//
//  LiveTextImageView.swift
//  Clipboard
//
//  Created by crown on 2026/1/3.
//

import AppKit
import SwiftUI
import VisionKit

struct LiveTextImageView: NSViewRepresentable {
    let imageData: Data

    func makeNSView(context _: Context) -> LiveTextContainerView {
        LiveTextContainerView(imageData: imageData)
    }

    func updateNSView(_ nsView: LiveTextContainerView, context _: Context) {
        nsView.updateImage(imageData)
    }
}

class LiveTextContainerView: NSView, ImageAnalysisOverlayViewDelegate {
    private var imageView: NSImageView?
    private var overlayView: ImageAnalysisOverlayView?
    private var currentImageData: Data?
    private var analysisTask: Task<Void, Never>?

    private static let sharedAnalyzer: ImageAnalyzer? = {
        guard ImageAnalyzer.isSupported else { return nil }
        return ImageAnalyzer()
    }()

    init(imageData: Data) {
        super.init(frame: .zero)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        setupViews(with: imageData)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        analysisTask?.cancel()
    }

    private func setupViews(with imageData: Data) {
        currentImageData = imageData

        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        addSubview(imageView)
        self.imageView = imageView

        let overlayView = ImageAnalysisOverlayView()
        overlayView.delegate = self
        overlayView.preferredInteractionTypes = .automatic
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(overlayView)
        self.overlayView = overlayView

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            overlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: imageView.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
        ])

        if let nsImage = NSImage(data: imageData) {
            imageView.image = nsImage
            analyzeImage(nsImage)
        } else {
            let config = NSImage.SymbolConfiguration(pointSize: 64, weight: .regular)
            imageView.image = NSImage(systemSymbolName: "photo.badge.arrow.down", accessibilityDescription: nil)?.withSymbolConfiguration(config)
            imageView.imageScaling = .scaleNone
            imageView.contentTintColor = .secondaryLabelColor
        }
    }

    func updateImage(_ imageData: Data) {
        guard imageData != currentImageData else { return }
        currentImageData = imageData

        analysisTask?.cancel()
        analysisTask = nil
        overlayView?.analysis = nil

        if let nsImage = NSImage(data: imageData) {
            imageView?.image = nsImage
            imageView?.imageScaling = .scaleProportionallyUpOrDown
            imageView?.contentTintColor = nil
            analyzeImage(nsImage)
        } else {
            let config = NSImage.SymbolConfiguration(pointSize: 64, weight: .regular)
            imageView?.image = NSImage(systemSymbolName: "photo.badge.arrow.down", accessibilityDescription: nil)?.withSymbolConfiguration(config)
            imageView?.imageScaling = .scaleNone
            imageView?.contentTintColor = .secondaryLabelColor
        }
    }

    private func analyzeImage(_ nsImage: NSImage) {
        guard let analyzer = Self.sharedAnalyzer,
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return }

        analysisTask = Task { @MainActor [weak self] in
            let configuration = ImageAnalyzer.Configuration([.text, .machineReadableCode])

            do {
                let analysis = try await analyzer.analyze(cgImage, orientation: .up, configuration: configuration)
                guard !Task.isCancelled else { return }
                self?.overlayView?.analysis = analysis
                self?.overlayView?.trackingImageView = self?.imageView
                self?.overlayView?.setContentsRectNeedsUpdate()
            } catch {
                if !Task.isCancelled {
                    log.warn("Image analysis failed: \(error)")
                }
            }
        }
    }

    override func layout() {
        super.layout()
        overlayView?.setContentsRectNeedsUpdate()
    }

    // MARK: - ImageAnalysisOverlayViewDelegate

    func contentsRect(for _: ImageAnalysisOverlayView) -> CGRect {
        guard let image = imageView?.image,
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

        let xOffset = (viewSize.width - renderedWidth) / 2 / viewSize.width
        let yOffset = (viewSize.height - renderedHeight) / 2 / viewSize.height

        return CGRect(
            x: xOffset,
            y: yOffset,
            width: renderedWidth / viewSize.width,
            height: renderedHeight / viewSize.height
        )
    }

    override var intrinsicContentSize: NSSize {
        guard let image = imageView?.image else { return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric) }

        let maxWidth = Const.maxPreviewWidth - Const.space12 * 2
        let maxHeight = Const.maxContentHeight
        let imageSize = image.size

        guard imageSize.width > 0, imageSize.height > 0 else {
            return NSSize(width: maxWidth, height: maxHeight)
        }

        let widthRatio = maxWidth / imageSize.width
        let heightRatio = maxHeight / imageSize.height
        let scale = min(widthRatio, heightRatio, 1.0)

        return NSSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }
}
