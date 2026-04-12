//
//  CardBottomView.swift
//  Clipboard
//
//  Created by crown on 2026/4/12.
//

import AppKit
import SnapKit

// MARK: - CardBottomView

final class CardBottomView: NSView {
    private var currentView: NSView?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func configure(with model: PasteboardModel, keyword: String = "") {
        currentView?.removeFromSuperview()
        currentView = nil

        guard let view = makeBottomView(for: model, keyword: keyword) else { return }
        addSubview(view)
        view.snp.makeConstraints { $0.edges.equalToSuperview() }
        currentView = view
    }

    func reset() {
        currentView?.removeFromSuperview()
        currentView = nil
    }

    // MARK: - Mouse passthrough

    override func mouseDown(with event: NSEvent) {
        nextResponder?.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        nextResponder?.mouseUp(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        nextResponder?.mouseDragged(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }

    // MARK: - Factory

    private func makeBottomView(for model: PasteboardModel, keyword: String) -> NSView? {
        switch model.type {
        case .image:
            return CardImageBottomView(introString: model.introString())
        case .link:
            if PasteUserDefaults.enableLinkPreview { return nil }
            return CardCommonBottomView(model: model)
        case .file:
            return CardFileBottomView(model: model, keyword: keyword)
        case .color:
            return nil
        default:
            return CardCommonBottomView(model: model)
        }
    }
}

// MARK: - CardImageBottomView

private final class CardImageBottomView: NSView {
    private lazy var label: PaddedTextField = {
        let field = PaddedTextField(padding: NSEdgeInsets(
            top: 2, left: Const.space6,
            bottom: 2, right: Const.space6
        ))
        field.font = .preferredFont(forTextStyle: .callout)
        field.textColor = .secondaryLabelColor
        field.lineBreakMode = .byTruncatingTail
        field.wantsLayer = true
        field.layer?.backgroundColor = NSColor.unemphasizedSelectedContentBackgroundColor.withAlphaComponent(0.6).cgColor
        field.layer?.cornerRadius = 6.0
        field.layer?.cornerCurve = .continuous
        return field
    }()

    init(introString: String) {
        super.init(frame: .zero)
        label.stringValue = introString

        addSubview(label)
        label.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(Const.space8)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func mouseDown(with event: NSEvent) {
        nextResponder?.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        nextResponder?.mouseUp(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        nextResponder?.mouseDragged(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }
}

// MARK: - CardFileBottomView

private final class CardFileBottomView: NSView {
    private lazy var firstLineLabel: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.font = .preferredFont(forTextStyle: .callout)
        field.lineBreakMode = .byCharWrapping
        field.maximumNumberOfLines = 1
        return field
    }()

    private lazy var secondLineLabel: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.font = .preferredFont(forTextStyle: .callout)
        field.lineBreakMode = .byTruncatingHead
        field.maximumNumberOfLines = 1
        return field
    }()

    private lazy var stack: NSStackView = {
        let sv = NSStackView(views: [firstLineLabel, secondLineLabel])
        sv.orientation = .vertical
        sv.alignment = .leading
        sv.spacing = 0
        sv.distribution = .fill
        return sv
    }()

    init(model: PasteboardModel, keyword: String) {
        super.init(frame: .zero)

        guard let filePaths = model.cachedFilePaths, !filePaths.isEmpty else { return }

        let (_, textColor) = model.colors()
        firstLineLabel.textColor = textColor
        secondLineLabel.textColor = textColor

        if filePaths.count > 1 {
            firstLineLabel.stringValue = model.introString()
            firstLineLabel.lineBreakMode = .byTruncatingTail
            secondLineLabel.isHidden = true
        } else {
            let text: String = model.introString()
            let maxWidth = Const.cardSize - Const.space12 * 2
            let font = firstLineLabel.font ?? .preferredFont(forTextStyle: .callout)
            let (line1, line2) = splitTextIntoTwoLines(text, font: font, maxWidth: maxWidth)

            if keyword.isEmpty {
                firstLineLabel.stringValue = line1
                secondLineLabel.stringValue = line2
            } else {
                firstLineLabel.attributedStringValue = highlightLine(line1, keyword: keyword, label: firstLineLabel, textColor: textColor)
                secondLineLabel.attributedStringValue = highlightLine(line2, keyword: keyword, label: secondLineLabel, textColor: textColor)
            }

            secondLineLabel.isHidden = line2.isEmpty
        }

        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Const.space12)
            make.bottom.equalToSuperview().inset(secondLineLabel.stringValue.isEmpty ? Const.space8 : Const.space4)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func mouseDown(with event: NSEvent) {
        nextResponder?.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        nextResponder?.mouseUp(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        nextResponder?.mouseDragged(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }

    private func splitTextIntoTwoLines(_ text: String, font: NSFont, maxWidth: CGFloat) -> (String, String) {
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

        let candidateRange = max(0, lo - 20) ..< lo
        if let separatorIdx = chars[candidateRange].lastIndex(of: "/") {
            let breakAt = chars.distance(from: chars.startIndex, to: separatorIdx) + 1
            if breakAt > 0 {
                return (String(chars[..<breakAt]), String(chars[breakAt...]))
            }
        }

        return (String(chars[..<lo]), String(chars[lo...]))
    }

    private func highlightLine(_ text: String, keyword: String, label: NSTextField, textColor: NSColor) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = label.lineBreakMode
        let font = label.font ?? .preferredFont(forTextStyle: .callout)
        let mutable = NSMutableAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
        ])
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return mutable }
        let source = text as NSString
        let options: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
        var searchRange = NSRange(location: 0, length: source.length)
        while searchRange.length > 0 {
            let found = source.range(of: trimmed, options: options, range: searchRange, locale: .current)
            guard found.location != NSNotFound else { break }
            mutable.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.65), range: found)
            let next = found.location + found.length
            guard next < source.length else { break }
            searchRange = NSRange(location: next, length: source.length - next)
        }
        return mutable
    }
}

// MARK: - CardCommonBottomView

final class CardCommonBottomView: NSView {
    private lazy var gradientLayer = CAGradientLayer()

    private lazy var label: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.font = .preferredFont(forTextStyle: .callout)
        field.alignment = .center
        field.lineBreakMode = .byTruncatingTail
        return field
    }()

    private var needsMask: Bool = false

    init(model: PasteboardModel) {
        super.init(frame: .zero)
        wantsLayer = true

        let (baseColor, textColor) = model.colors()
        label.textColor = textColor
        label.stringValue = model.introString()

        needsMask = model.needsBottomMask {
            ContentMaskCalculator.needsMask(for: model)
        }

        if needsMask {
            layer?.addSublayer(gradientLayer)
            updateGradient(baseColor: baseColor)
        }

        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Const.space12)
            make.bottom.equalToSuperview().inset(Const.space12)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsLayout = true
    }

    override func mouseDown(with event: NSEvent) {
        nextResponder?.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        nextResponder?.mouseUp(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        nextResponder?.mouseDragged(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }

    private func updateGradient(baseColor: NSColor) {
        let resolved = baseColor.usingColorSpace(.sRGB) ?? baseColor
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.colors = [
            resolved.cgColor,
            resolved.cgColor,
            resolved.withAlphaComponent(0.8).cgColor,
            resolved.withAlphaComponent(0.0).cgColor,
        ]
        gradientLayer.locations = [0.0, 0.6, 0.9, 1.0]
    }
}

// MARK: - ContentMaskCalculator

private enum ContentMaskCalculator {
    static func needsMask(for model: PasteboardModel) -> Bool {
        guard model.pasteboardType.isText() else { return false }

        let contentTopPadding = Const.space8
        let contentHeightBeforeBottomOverlay = Const.cntSize - Const.bottomSize
        let contentTextHeight = calculateContentTextHeight(model: model)

        return (contentTopPadding + contentTextHeight) > contentHeightBeforeBottomOverlay
    }

    private static func calculateContentTextHeight(model: PasteboardModel) -> CGFloat {
        let availableWidth = Const.cardSize - Const.space10 * 4
        let constraintRect = CGSize(
            width: max(0, availableWidth),
            height: .greatestFiniteMagnitude
        )

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let defaultFont = NSFont.preferredFont(forTextStyle: .body)
        let measured = makeMeasuringAttributedString(
            base: model.attributeString,
            defaultFont: defaultFont,
            paragraphStyle: paragraphStyle
        )

        let boundingBox = measured.boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(boundingBox.height)
    }

    private static func makeMeasuringAttributedString(
        base: NSAttributedString,
        defaultFont: NSFont,
        paragraphStyle: NSParagraphStyle
    ) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: base)

        if mutable.string.contains("\r\n") {
            mutable.mutableString.replaceOccurrences(
                of: "\r\n",
                with: "\n",
                options: [],
                range: NSRange(location: 0, length: mutable.length)
            )
        }
        if mutable.string.hasSuffix("\n") {
            mutable.append(NSAttributedString(string: " ", attributes: [.font: defaultFont]))
        }
        if mutable.length > 0,
           mutable.attribute(.font, at: 0, effectiveRange: nil) == nil
        {
            mutable.addAttribute(.font, value: defaultFont, range: NSRange(location: 0, length: mutable.length))
        }
        mutable.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: mutable.length))
        return mutable
    }
}

// MARK: - PaddedTextField

private final class PaddedTextField: NSTextField {
    let padding: NSEdgeInsets

    init(padding: NSEdgeInsets) {
        self.padding = padding
        super.init(frame: .zero)
        isEditable = false
        isSelectable = false
        isBordered = false
        drawsBackground = false
        cell = PaddedTextFieldCell(padding: padding)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width += padding.left + padding.right
        size.height += padding.top + padding.bottom
        return size
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}

private final class PaddedTextFieldCell: NSTextFieldCell {
    let padding: NSEdgeInsets

    init(padding: NSEdgeInsets) {
        self.padding = padding
        super.init(textCell: "")
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError()
    }

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        super.drawingRect(forBounds: rect.insetBy(dx: padding.left, dy: padding.top))
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        super.titleRect(forBounds: rect.insetBy(dx: padding.left, dy: padding.top))
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: rect.insetBy(dx: padding.left, dy: padding.top), in: controlView, editor: textObj, delegate: delegate, event: event)
    }
}
