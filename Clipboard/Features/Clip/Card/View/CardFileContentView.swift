//
//  CardFileContentView.swift
//  Clipboard
//

import AppKit
import SnapKit

// MARK: - CardFileContentView

final class CardFileContentView: NSView, PassthroughMouseEvents {
    private var thumbnailView: CardFileThumbnailView?
    private var multiView: CardMultipleFilesView?

    init(model: PasteboardModel) {
        super.init(frame: .zero)

        if let filePaths = model.cachedFilePaths, !filePaths.isEmpty {
            if filePaths.count > 1 {
                let view = CardMultipleFilesView(filePaths: filePaths)
                multiView = view
                addSubview(view)
                view.snp.makeConstraints { $0.edges.equalToSuperview() }
            } else {
                let view = CardFileThumbnailView(filePath: filePaths[0])
                thumbnailView = view
                addSubview(view)
                view.snp.makeConstraints { make in
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
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyDown
        return view
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
        let view = NSImageView()
        view.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
        view.contentTintColor = NSColor.controlAccentColor.withAlphaComponent(0.8)
        view.imageScaling = .scaleProportionallyUpOrDown
        return view
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
