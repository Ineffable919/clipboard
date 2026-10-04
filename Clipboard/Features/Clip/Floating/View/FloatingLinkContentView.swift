//
//  FloatingLinkContentView.swift
//  Clipboard
//

import AppKit
@preconcurrency import LinkPresentation
import SnapKit

// MARK: - FloatingLinkContentView

final class FloatingLinkContentView: NSView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let urlLabel = NSTextField(labelWithString: "")
    private var loadTask: Task<Void, Never>?
    private let displayMode: FloatingDisplayMode

    init(model: PasteboardModel, keyword: String, displayMode: FloatingDisplayMode) {
        self.displayMode = displayMode
        super.init(frame: .zero)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
        iconView.contentTintColor = .secondaryLabelColor
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        addSubview(textStack)
        textStack.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Const.space6)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        urlLabel.font = .systemFont(ofSize: NSFont.labelFontSize, weight: .regular)
        urlLabel.textColor = .secondaryLabelColor
        urlLabel.lineBreakMode = .byTruncatingMiddle
        urlLabel.maximumNumberOfLines = 1

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(urlLabel)
        if displayMode == .minimal {
            urlLabel.isHidden = true
            titleLabel.snp.makeConstraints { $0.width.equalTo(textStack) }
        }

        let urlString = model.attributeString.string
        if keyword.isEmpty {
            urlLabel.stringValue = urlString
        } else {
            urlLabel.attributedStringValue = model.highlightedPlainText(keyword: keyword)
        }

        loadMetadata(for: model, urlString: urlString)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit { loadTask?.cancel() }

    private func loadMetadata(for model: PasteboardModel, urlString: String) {
        if let cached = model.cachedLinkMetadata {
            applyMetadata(title: cached.title, icon: cached.iconImage, urlString: urlString)
        } else {
            applyMetadata(title: nil, icon: nil, urlString: urlString)
            loadTask = Task { @MainActor [weak self] in
                guard let url = URL(string: urlString) else { return }
                let metadata = await FloatingLinkContentView.fetchMetadata(for: url)
                guard !Task.isCancelled, let self else { return }
                model.cachedLinkMetadata = metadata
                applyMetadata(title: metadata.title, icon: metadata.iconImage, urlString: urlString)
            }
        }
    }

    private func applyMetadata(title: String?, icon: NSImage?, urlString: String) {
        let title = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        titleLabel.stringValue = title.flatMap { $0.isEmpty ? nil : $0 }
            ?? URL(string: urlString)?.host() ?? urlString
        if displayMode == .minimal {
            toolTip = "\(titleLabel.stringValue)\n\(urlString)"
        }
        if let icon {
            iconView.image = icon
            iconView.contentTintColor = nil
        }
    }

    @preconcurrency
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
            let icon: NSImage? = await withCheckedContinuation { cont in
                if let source = metadata.iconProvider ?? metadata.imageProvider {
                    source.loadObject(ofClass: NSImage.self) { img, _ in
                        cont.resume(returning: img as? NSImage)
                    }
                } else {
                    cont.resume(returning: nil)
                }
            }
            return LinkPreviewMetadata(title: metadata.title, previewImage: nil, iconImage: icon)
        } catch {
            return LinkPreviewMetadata(title: nil, previewImage: nil, iconImage: nil)
        }
    }
}
