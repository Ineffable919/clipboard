//
//  PreviewFooterBar.swift
//  Clipboard
//
//  预览底部栏：信息标签、文件大小、在 Finder 中显示、在浏览器中打开
//

import AppKit
import SnapKit

// MARK: - PreviewFooterBar

final class PreviewFooterBar: NSView {
    static let minimumHeight: CGFloat = 24
    private static let infoMaxWidth =
        (Const.maxPreviewWidth - Const.space12 * 2) * 0.7

    // MARK: - Callbacks

    var onShowInFinder: (() -> Void)?
    var onOpenInBrowser: (() -> Void)?
    private var statisticsTask: Task<Void, Never>?

    // MARK: - Subviews

    private let firstLineLabel: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.textColor = .secondaryLabelColor
        field.lineBreakMode = .byCharWrapping
        field.maximumNumberOfLines = 1
        return field
    }()

    private let secondLineLabel: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.textColor = .secondaryLabelColor
        field.lineBreakMode = .byTruncatingHead
        field.maximumNumberOfLines = 1
        return field
    }()

    private lazy var infoStack: NSStackView = {
        let stack = NSStackView(views: [firstLineLabel, secondLineLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.distribution = .fill
        return stack
    }()

    private let finderButton: PreviewPillButton = {
        let btn = PreviewPillButton(title: String(localized: .showInFinder))
        btn.isHidden = true
        return btn
    }()

    private let browserButton: PreviewPillButton = {
        let btn = PreviewPillButton()
        btn.isHidden = true
        return btn
    }()

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        finderButton.onAction = { [weak self] in self?.onShowInFinder?() }
        browserButton.onAction = { [weak self] in self?.onOpenInBrowser?() }
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit {
        statisticsTask?.cancel()
    }

    // MARK: - Layout

    private func setupLayout() {
        addSubview(infoStack)
        addSubview(finderButton)
        addSubview(browserButton)

        infoStack.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(finderButton.snp.leading).offset(-Const.space8)
            make.width.lessThanOrEqualTo(Self.infoMaxWidth)
        }

        finderButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }

        browserButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
    }

    // MARK: - Public API

    var preferredHeight: CGFloat {
        let firstLineHeight = firstLineLabel.intrinsicContentSize.height
        let secondLineHeight = secondLineLabel.isHidden
            ? 0
            : secondLineLabel.intrinsicContentSize.height
        return max(Self.minimumHeight, ceil(firstLineHeight + secondLineHeight))
    }

    func configure(
        model: PasteboardModel,
        fileSize: String?,
        browserName: String?,
        defaultAppForFile _: String?
    ) {
        statisticsTask?.cancel()
        let isSingleFile = model.type == .file && model.fileSize() == 1
        let showLinkPreview = model.type == .link
            && PasteUserDefaults.enableLinkPreview
            && model.isLink

        firstLineLabel.maximumNumberOfLines = 1
        firstLineLabel.preferredMaxLayoutWidth = 0

        if isSingleFile, let path = model.cachedFilePaths?.first {
            setWrappedText(path, suffix: fileSize.map { " · \($0)" } ?? "")
        } else if showLinkPreview {
            setWrappedText(model.attributeString.string)
        } else if model.pasteboardType.isText(), !showLinkPreview {
            firstLineLabel.stringValue = model.introString()
            secondLineLabel.stringValue = ""
            secondLineLabel.isHidden = true
            let data = model.data
            let typeRawValue = model.pasteboardType.rawValue
            statisticsTask = Task { @MainActor [weak self] in
                let worker = Task.detached(priority: .utility) {
                    let text = EditTextLoader.load(data: data, typeRawValue: typeRawValue)
                    return TextStatistics(from: text)
                }
                let stats = await withTaskCancellationHandler {
                    await worker.value
                } onCancel: {
                    worker.cancel()
                }
                guard let self, !Task.isCancelled else { return }
                firstLineLabel.stringValue = stats.displayString
            }
        } else {
            firstLineLabel.stringValue = model.introString()
            secondLineLabel.stringValue = ""
            secondLineLabel.isHidden = true
        }

        finderButton.isHidden = !isSingleFile

        if showLinkPreview, let name = browserName {
            browserButton.title = String(localized: .openInApp(name))
            browserButton.isHidden = false
        } else {
            browserButton.isHidden = true
        }
    }

    // MARK: - Private

    private func setWrappedText(_ text: String, suffix: String = "") {
        let font = firstLineLabel.font ?? .systemFont(ofSize: NSFont.systemFontSize)
        let (line1, line2) = splitPathIntoTwoLines(
            text,
            suffix: suffix,
            font: font,
            maxWidth: Self.infoMaxWidth
        )
        firstLineLabel.stringValue = line1
        secondLineLabel.stringValue = line2
        secondLineLabel.isHidden = line2.isEmpty
    }

    private func splitPathIntoTwoLines(
        _ text: String,
        suffix: String,
        font: NSFont,
        maxWidth: CGFloat
    ) -> (String, String) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let fullText = text + suffix
        let explicitLines = text.split(
            omittingEmptySubsequences: false,
            whereSeparator: { $0.isNewline }
        )

        if explicitLines.count > 1 {
            let line1 = String(explicitLines[0])
            let line2 = explicitLines.dropFirst().joined(separator: "\n") + suffix
            return (line1, line2)
        }

        guard (fullText as NSString).size(withAttributes: attrs).width > maxWidth else {
            return (fullText, "")
        }

        let chars = Array(text)
        var lower = 0
        var upper = chars.count
        while lower < upper {
            let mid = (lower + upper + 1) / 2
            let sub = String(chars[..<mid])
            if (sub as NSString).size(withAttributes: attrs).width <= maxWidth {
                lower = mid
            } else {
                upper = mid - 1
            }
        }

        let line1 = String(chars[..<lower])
        let line2 = String(chars[lower...]) + suffix
        return (line1, line2)
    }
}
