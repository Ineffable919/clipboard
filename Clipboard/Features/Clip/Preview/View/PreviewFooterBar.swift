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
    // MARK: - Callbacks

    var onShowInFinder: (() -> Void)?
    var onOpenInBrowser: (() -> Void)?

    // MARK: - Subviews

    private let firstLineLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = .systemFont(ofSize: NSFont.systemFontSize)
        f.textColor = .secondaryLabelColor
        f.lineBreakMode = .byCharWrapping
        f.maximumNumberOfLines = 1
        return f
    }()

    private let secondLineLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = .systemFont(ofSize: NSFont.systemFontSize)
        f.textColor = .secondaryLabelColor
        f.lineBreakMode = .byTruncatingHead
        f.maximumNumberOfLines = 1
        return f
    }()

    private lazy var infoStack: NSStackView = {
        let sv = NSStackView(views: [firstLineLabel, secondLineLabel])
        sv.orientation = .vertical
        sv.alignment = .leading
        sv.spacing = 0
        sv.distribution = .fill
        return sv
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

    // MARK: - Layout

    private func setupLayout() {
        addSubview(infoStack)
        addSubview(finderButton)
        addSubview(browserButton)

        infoStack.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(finderButton.snp.leading).offset(-Const.space8)
            make.width.lessThanOrEqualTo((Const.maxPreviewWidth - Const.space12 * 2) * 0.7)
        }

        finderButton.snp.makeConstraints { make in
            make.trailing.equalTo(browserButton.snp.leading).offset(-Const.space6)
            make.centerY.equalToSuperview()
        }

        browserButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
    }

    // MARK: - Public API

    func configure(
        model: PasteboardModel,
        fileSize: String?,
        browserName: String?,
        defaultAppForFile _: String?
    ) {
        let isSingleFile = model.type == .file && model.fileSize() == 1
        let showLinkPreview = model.type == .link
            && PasteUserDefaults.enableLinkPreview
            && model.isLink

        if isSingleFile, let path = model.cachedFilePaths?.first {
            let suffix = fileSize.map { " · \($0)" } ?? ""
            let maxWidth = (Const.maxPreviewWidth - Const.space12 * 2) * 0.7
            let font = firstLineLabel.font ?? .systemFont(ofSize: NSFont.systemFontSize)
            let (line1, line2) = splitPathIntoTwoLines(
                path, suffix: suffix, font: font, maxWidth: maxWidth
            )
            firstLineLabel.stringValue = line1
            secondLineLabel.stringValue = line2
            secondLineLabel.isHidden = line2.isEmpty
        } else if model.pasteboardType.isText(), !showLinkPreview {
            let stats = TextStatistics(from: model.plainText)
            firstLineLabel.stringValue = stats.displayString
            secondLineLabel.stringValue = ""
            secondLineLabel.isHidden = true
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

    private func splitPathIntoTwoLines(
        _ text: String,
        suffix: String,
        font: NSFont,
        maxWidth: CGFloat
    ) -> (String, String) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let fullText = text + suffix

        // 整体一行放得下，直接返回
        guard (fullText as NSString).size(withAttributes: attrs).width > maxWidth else {
            return (fullText, "")
        }

        // 先只对路径做分行
        let chars = Array(text)
        var lo = 0
        var hi = chars.count
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            let sub = String(chars[..<mid])
            if (sub as NSString).size(withAttributes: attrs).width <= maxWidth {
                lo = mid
            } else {
                hi = mid - 1
            }
        }

        let line1 = String(chars[..<lo])
        let line2 = String(chars[lo...]) + suffix
        return (line1, line2)
    }
}
