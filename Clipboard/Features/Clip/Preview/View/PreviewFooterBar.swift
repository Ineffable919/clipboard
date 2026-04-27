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

    private let fileSizeLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = .systemFont(ofSize: NSFont.systemFontSize)
        f.textColor = .secondaryLabelColor
        f.isHidden = true
        return f
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
        addSubview(fileSizeLabel)
        addSubview(finderButton)
        addSubview(browserButton)

        infoStack.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(fileSizeLabel.snp.leading).offset(-Const.space8)
            make.width.lessThanOrEqualTo((Const.maxPreviewWidth - Const.space12 * 2) * 0.7)
        }

        fileSizeLabel.snp.makeConstraints { make in
            make.trailing.equalTo(finderButton.snp.leading).offset(-Const.space6)
            make.centerY.equalToSuperview()
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

        // 信息标签
        if isSingleFile, let path = model.cachedFilePaths?.first {
            let maxWidth = (Const.maxPreviewWidth - Const.space12 * 2) * 0.7
            let font = firstLineLabel.font ?? .systemFont(ofSize: NSFont.systemFontSize)
            let (line1, line2) = splitPathIntoTwoLines(path, font: font, maxWidth: maxWidth)
            firstLineLabel.stringValue = line1
            secondLineLabel.stringValue = line2
            secondLineLabel.isHidden = line2.isEmpty
        } else if model.pasteboardType.isText(), !showLinkPreview {
            let stats = TextStatistics(from: model.attributeString.string)
            firstLineLabel.stringValue = stats.displayString
            secondLineLabel.stringValue = ""
            secondLineLabel.isHidden = true
        } else {
            firstLineLabel.stringValue = model.introString()
            secondLineLabel.stringValue = ""
            secondLineLabel.isHidden = true
        }

        // 文件大小
        if isSingleFile, let size = fileSize {
            fileSizeLabel.stringValue = size
            fileSizeLabel.isHidden = false
        } else {
            fileSizeLabel.isHidden = true
        }

        // Finder 按钮
        finderButton.isHidden = !isSingleFile

        // 浏览器按钮
        if showLinkPreview, let name = browserName {
            browserButton.title = String(localized: .openInApp(name))
            browserButton.isHidden = false
        } else {
            browserButton.isHidden = true
        }
    }

    // MARK: - Private

    /// 将长路径拆分为两行显示，第一行尽量填满可用宽度
    private func splitPathIntoTwoLines(
        _ text: String,
        font: NSFont,
        maxWidth: CGFloat
    ) -> (String, String) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        guard (text as NSString).size(withAttributes: attrs).width > maxWidth else {
            return (text, "")
        }

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

        return (String(chars[..<lo]), String(chars[lo...]))
    }
}
