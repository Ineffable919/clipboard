//
//  FloatingCardRowView+Content.swift
//  Clipboard
//

import AppKit
import SnapKit

extension FloatingCardRowView {
    func makeContentSubview(for model: PasteboardModel, keyword: String) -> NSView {
        switch model.type {
        case .color:
            return FloatingColorContentView(model: model)
        case .image:
            return FloatingImageContentView(model: model, displayMode: displayMode)
        case .file:
            return FloatingFileContentView(model: model)
        case .rich:
            if model.hasBgColor {
                return FloatingRichContentView(
                    model: model, keyword: keyword, maximumLines: displayMode == .standard ? 2 : 1
                )
            }
            return FloatingTextContentView(
                model: model, keyword: keyword, maximumLines: displayMode == .standard ? 0 : 1
            )
        case .link:
            if PasteUserDefaults.enableLinkPreview {
                return FloatingLinkContentView(model: model, keyword: keyword, displayMode: displayMode)
            }
            return FloatingTextContentView(
                model: model, keyword: keyword, maximumLines: displayMode == .standard ? 0 : 1
            )
        case .string:
            return FloatingTextContentView(
                model: model, keyword: keyword, maximumLines: displayMode == .standard ? 0 : 1
            )
        case .none:
            return NSView()
        }
    }
}

// MARK: - FloatingTextContentView

final class FloatingTextContentView: NSView {
    private let textField = NSTextField(labelWithString: "")

    init(model: PasteboardModel, keyword: String, maximumLines: Int) {
        super.init(frame: .zero)
        textField.cell = VerticallyCenteredTextFieldCell()
        textField.cell?.usesSingleLineMode = maximumLines == 1
        textField.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = maximumLines
        textField.cell?.truncatesLastVisibleLine = true
        addSubview(textField)
        textField.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        update(keyword: keyword, model: model)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func update(keyword: String, model: PasteboardModel) {
        let text = keyword.isEmpty
            ? model.plainTextAttributedString
            : model.highlightedNSAttributedString(keyword: keyword)
        if textField.maximumNumberOfLines == 1, model.pasteboardType == .string {
            let preview = NSMutableAttributedString(attributedString: text)
            preview.addAttribute(
                .font, value: NSFont.systemFont(ofSize: 12), range: NSRange(location: 0, length: preview.length)
            )
            textField.attributedStringValue = preview
        } else {
            textField.attributedStringValue = text
        }
    }
}

// MARK: - FloatingRichContentView

final class FloatingRichContentView: NSView {
    private let textField = NSTextField(labelWithString: "")

    init(model: PasteboardModel, keyword: String, maximumLines: Int) {
        super.init(frame: .zero)
        textField.cell = VerticallyCenteredTextFieldCell()
        textField.cell?.usesSingleLineMode = maximumLines == 1
        textField.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = maximumLines
        textField.cell?.truncatesLastVisibleLine = true
        addSubview(textField)
        textField.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        update(keyword: keyword, model: model)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func update(keyword: String, model: PasteboardModel) {
        textField.attributedStringValue = model.highlightedRichText(keyword: keyword)
    }
}

// MARK: - FloatingColorContentView

private final class FloatingColorContentView: NSView {
    private let label = NSTextField(labelWithString: "")

    init(model: PasteboardModel) {
        super.init(frame: .zero)
        label.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.textColor = model.colors().1
        label.stringValue = model.colorDisplayText
        addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}

// MARK: - FloatingImageContentView

private final class FloatingImageContentView: NSView {
    private let imageView = NSView()
    private let placeholder = NSImageView()
    private var loadTask: Task<Void, Never>?

    init(model: PasteboardModel, displayMode: FloatingDisplayMode) {
        super.init(frame: .zero)
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = displayMode == .standard ? 0 : 4
        imageView.layer?.masksToBounds = true
        imageView.layer?.contentsGravity = displayMode == .standard ? .resizeAspect : .resizeAspectFill
        imageView.isHidden = true
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            if displayMode == .standard {
                make.edges.equalToSuperview()
            } else {
                make.centerY.equalToSuperview()
                make.width.equalTo(64)
                make.height.equalToSuperview()
            }
        }

        if displayMode == .minimal {
            let photoIcon = NSImageView()
            photoIcon.image = NSImage(
                systemSymbolName: "photo", accessibilityDescription: String(localized: .image)
            )
            photoIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            photoIcon.contentTintColor = .systemBlue
            photoIcon.imageScaling = .scaleNone
            addSubview(photoIcon)
            photoIcon.snp.makeConstraints { make in
                make.leading.equalToSuperview()
                make.centerY.equalToSuperview()
                make.width.height.equalTo(20)
            }
            imageView.snp.makeConstraints { $0.leading.equalTo(photoIcon.snp.trailing).offset(Const.space8) }
        }

        placeholder.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
        placeholder.contentTintColor = .secondaryLabelColor
        placeholder.imageScaling = .scaleProportionallyUpOrDown
        addSubview(placeholder)
        placeholder.snp.makeConstraints { make in
            make.center.equalTo(imageView)
            make.width.height.equalTo(20)
        }

        loadTask = Task { @MainActor [weak self] in
            let image = await model.loadThumbnail()
            guard !Task.isCancelled, let self else { return }
            if let image {
                imageView.layer?.contents = image
                imageView.isHidden = false
                placeholder.isHidden = true
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit { loadTask?.cancel() }
}

// MARK: - FloatingFileContentView

private final class FloatingFileContentView: NSView {
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")

    init(model: PasteboardModel) {
        super.init(frame: .zero)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }

        nameLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.maximumNumberOfLines = 1
        addSubview(nameLabel)
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Const.space6)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        if let paths = model.cachedFilePaths, !paths.isEmpty {
            if paths.count > 1 {
                iconView.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
                iconView.contentTintColor = NSColor.controlAccentColor.withAlphaComponent(0.7)
                nameLabel.stringValue = String(localized: .fileCount(paths.count))
            } else if let path = paths.first {
                let url = URL(filePath: path)
                iconView.image = FileThumbnailService.shared.systemIcon(for: url)
                nameLabel.stringValue = url.lastPathComponent
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}
