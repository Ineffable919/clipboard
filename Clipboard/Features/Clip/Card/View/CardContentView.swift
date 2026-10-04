//
//  CardContentView.swift
//  Clipboard
//

import AppKit
import Combine
import SnapKit

// MARK: - NSTextView factory

private func makeCardTextView() -> PassthroughTextView {
    let view = PassthroughTextView(usingTextLayoutManager: false)
    view.isEditable = false
    view.isSelectable = false
    view.drawsBackground = false
    view.isHorizontallyResizable = false
    view.isVerticallyResizable = true
    view.textContainer?.widthTracksTextView = false
    view.textContainer?.heightTracksTextView = false
    view.textContainer?.lineFragmentPadding = 0
    view.textContainer?.lineBreakMode = .byWordWrapping
    view.textContainer?.containerSize = CGSize(
        width: Const.cardSize - Const.space10 * 2,
        height: .greatestFiniteMagnitude
    )
    view.textContainerInset = NSSize(width: Const.space10, height: Const.space8)
    view.layoutManager?.allowsNonContiguousLayout = false
    return view
}

// MARK: - CardContentView

final class CardContentView: NSView, PassthroughMouseEvents {
    private var currentContentView: NSView?
    private nonisolated(unsafe) var currentModel: PasteboardModel?
    private nonisolated(unsafe) var currentKeyword: String = ""

    private var linkPreviewCancellable: AnyCancellable?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        observeLinkPreviewSetting()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: Configure

    func configure(with model: PasteboardModel, keyword: String = "") {
        let isSameModel = currentModel?.uniqueId == model.uniqueId
        let isSameKeyword = currentKeyword == keyword

        currentModel = model
        currentKeyword = keyword
        needsDisplay = true

        guard !isSameModel || !isSameKeyword else { return }

        if isSameModel {
            updateKeyword(keyword, in: currentContentView)
        } else {
            replaceContentView(for: model, keyword: keyword)
        }
    }

    func resetContent() {
        cancelCurrentLoad()
        currentContentView?.removeFromSuperview()
        currentContentView = nil
        currentModel = nil
        currentKeyword = ""
        needsDisplay = true
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let color: NSColor = currentModel == nil || currentModel?.type == .color
                ? .clear : .textBackgroundColor
            layer?.backgroundColor = color.cgColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    // MARK: Private

    private func observeLinkPreviewSetting() {
        linkPreviewCancellable = UserDefaults.standard
            .publisher(for: \.enableLinkPreview)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self,
                      let model = currentModel,
                      model.type == .link
                else { return }
                replaceContentView(for: model, keyword: currentKeyword)
            }
    }

    private func replaceContentView(for model: PasteboardModel, keyword: String) {
        cancelCurrentLoad()
        currentContentView?.removeFromSuperview()
        currentContentView = nil

        let view = makeContentView(for: model, keyword: keyword)
        addSubview(view)
        view.snp.makeConstraints { $0.edges.equalToSuperview() }
        currentContentView = view
    }

    private func updateKeyword(_ keyword: String, in view: NSView?) {
        guard let model = currentModel else { return }
        switch view {
        case let view as CardStringContentView:
            view.updateKeyword(keyword, model: model)
        case let view as CardRichContentView:
            view.updateKeyword(keyword, model: model)
        case let view as CardImageContentView:
            view.updateKeyword(keyword, model: model)
        case let view as CardLinkPreviewContentView:
            view.updateKeyword(keyword, model: model)
        default:
            break
        }
    }

    private func cancelCurrentLoad() {
        if let imageView = currentContentView as? CardImageContentView {
            imageView.cancelLoad()
        } else if let linkView = currentContentView as? CardLinkPreviewContentView {
            linkView.cancelLoad()
        } else if let fileView = currentContentView as? CardFileContentView {
            fileView.cancelLoad()
        }
    }

    private func makeContentView(for model: PasteboardModel, keyword: String) -> NSView {
        switch model.type {
        case .color:
            return CardColorContentView(model: model)
        case .image:
            return CardImageContentView(model: model, keyword: keyword)
        case .file:
            return CardFileContentView(model: model)
        case .rich:
            if model.hasBgColor {
                return CardRichContentView(model: model, keyword: keyword)
            } else {
                return CardStringContentView(model: model, keyword: keyword)
            }
        case .link:
            if PasteUserDefaults.enableLinkPreview {
                return CardLinkPreviewContentView(model: model, keyword: keyword)
            }
            return CardStringContentView(model: model, keyword: keyword)
        case .string:
            return CardStringContentView(model: model, keyword: keyword)
        case .none:
            return NSView()
        }
    }
}

// MARK: - CardStringContentView

final class CardStringContentView: NSView, PassthroughMouseEvents {
    private lazy var textView: PassthroughTextView = makeCardTextView()

    init(model: PasteboardModel, keyword: String) {
        super.init(frame: .zero)
        addSubview(textView)
        textView.snp.makeConstraints { $0.edges.equalToSuperview() }

        updateKeyword(keyword, model: model)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func updateKeyword(_ keyword: String, model: PasteboardModel) {
        let attributed: NSAttributedString = keyword.isEmpty
            ? model.plainTextAttributedString
            : model.highlightedNSAttributedString(keyword: keyword)
        textView.textStorage?.setAttributedString(attributed)
        if model.pasteboardType == .string {
            textView.font = .preferredFont(forTextStyle: .body)
        }
    }
}

// MARK: - PassthroughTextView

private final class PassthroughTextView: NSTextView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        isSelectable ? super.hitTest(point) : nil
    }

    override func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }
}

// MARK: - CardRichContentView

final class CardRichContentView: NSView, PassthroughMouseEvents {
    private lazy var textView: PassthroughTextView = makeCardTextView()
    private let model: PasteboardModel

    init(model: PasteboardModel, keyword: String) {
        self.model = model
        super.init(frame: .zero)

        addSubview(textView)
        textView.snp.makeConstraints { $0.edges.equalToSuperview() }
        textView.textStorage?.setAttributedString(model.highlightedRichText(keyword: keyword))
        updateBackground()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func updateKeyword(_ keyword: String, model: PasteboardModel) {
        textView.textStorage?.setAttributedString(model.highlightedRichText(keyword: keyword))
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackground()
    }

    private func updateBackground() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let background = model.richBackground(on: .textBackgroundColor)
            textView.drawsBackground = background != nil
            textView.backgroundColor = background ?? .textBackgroundColor
        }
    }
}

// MARK: - CardColorContentView

final class CardColorContentView: NSView, PassthroughMouseEvents {
    private lazy var label: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.font = .systemFont(ofSize: NSFont.systemFontSize + 4, weight: .medium)
        field.alignment = .center
        field.lineBreakMode = .byTruncatingTail
        return field
    }()

    private var dynamicBgColor: NSColor = .controlBackgroundColor

    init(model: PasteboardModel) {
        super.init(frame: .zero)
        wantsLayer = true

        dynamicBgColor = model.cachedBackgroundColor ?? .controlBackgroundColor
        applyColors()

        label.stringValue = model.colorDisplayText
        addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(Const.space8)
            make.trailing.lessThanOrEqualToSuperview().offset(-Const.space8)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
    }

    private func applyColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = dynamicBgColor.cgColor
            label.textColor = contrastingNSColor(for: dynamicBgColor)
        }
    }
}
