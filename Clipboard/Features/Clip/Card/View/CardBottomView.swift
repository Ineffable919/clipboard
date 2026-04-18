//
//  CardBottomView.swift
//  Clipboard
//
//  Created by crown on 2026/4/12.
//

import AppKit
import SnapKit

// MARK: - CardBottomView

final class CardBottomView: NSView, PassthroughMouseEvents {
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

private final class CardImageBottomView: NSView, PassthroughMouseEvents {
    private lazy var label: PaddedTextField = {
        let field = PaddedTextField(padding: NSEdgeInsets(
            top: 2, left: Const.space6,
            bottom: 2, right: Const.space6
        ))
        field.font = .preferredFont(forTextStyle: .callout)
        field.textColor = .secondaryLabelColor
        field.lineBreakMode = .byTruncatingTail
        field.wantsLayer = true
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

        updateLabelBackground()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateLabelBackground()
    }

    private func updateLabelBackground() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            label.layer?.backgroundColor = NSColor.unemphasizedSelectedContentBackgroundColor
                .cgColor
        }
    }
}

// MARK: - CardFileBottomView

private final class CardFileBottomView: NSView, PassthroughMouseEvents {
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
        sv.alignment = .centerX
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

final class CardCommonBottomView: NSView, PassthroughMouseEvents {
    private lazy var gradientLayer = CAGradientLayer()

    private lazy var label: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.font = .preferredFont(forTextStyle: .callout)
        field.alignment = .center
        field.lineBreakMode = .byTruncatingTail
        return field
    }()

    private var needsMask: Bool = false
    private var baseColor: NSColor = .controlBackgroundColor

    init(model: PasteboardModel) {
        super.init(frame: .zero)
        wantsLayer = true

        let (base, textColor) = model.colors()
        baseColor = base
        label.textColor = textColor
        label.stringValue = model.introString()

        needsMask = model.needsBottomMask {
            ContentMaskCalculator.needsMask(for: model)
        }

        if needsMask {
            layer?.addSublayer(gradientLayer)
            updateGradient()
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
        if needsMask {
            updateGradient()
        }
    }

    private func updateGradient() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let resolved = baseColor.usingColorSpace(.sRGB) ?? baseColor
            gradientLayer.colors = [
                resolved.cgColor,
                resolved.cgColor,
                resolved.withAlphaComponent(0.8).cgColor,
                resolved.withAlphaComponent(0.0).cgColor,
            ]
        }
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.locations = [0.0, 0.6, 0.7, 1.0]
    }
}
