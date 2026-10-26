//
//  FloatingLinkContentView.swift
//  Clipboard
//

import AppKit
import SnapKit

// MARK: - FloatingLinkContentView

final class FloatingLinkContentView: NSView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let urlLabel = NSTextField(labelWithString: "")
    private lazy var previewRequest = LinkPreviewRequest(view: self)
    private let displayMode: FloatingDisplayMode

    init(model: PasteboardModel, keyword: String, displayMode: FloatingDisplayMode) {
        self.displayMode = displayMode
        super.init(frame: .zero)

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

    private func setupViews() {
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
    }

    private func configure(with model: PasteboardModel, keyword: String) {
        let urlString = model.attributeString.string
        if keyword.isEmpty {
            urlLabel.stringValue = urlString
        } else {
            urlLabel.attributedStringValue = model.highlightedPlainText(keyword: keyword)
        }

        loadMetadata(urlString: urlString)
    }

    private func loadMetadata(urlString: String) {
        applyMetadata(title: nil, icon: nil, urlString: urlString)
        previewRequest.load { [weak self] in
            guard let url = URL(string: urlString) else { return }
            let metadata = await LinkPreviewLoader.fetch(for: url, imagePolicy: .iconOrPreview)
            guard !Task.isCancelled, let self else { return }
            applyMetadata(title: metadata.title, icon: metadata.iconImage, urlString: urlString)
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
}
