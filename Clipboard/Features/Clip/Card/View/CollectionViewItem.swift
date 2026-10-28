//
//  CollectionViewItem.swift
//  Clipboard
//
//  Created by crown on 2026/4/10.
//

import AppKit
import Combine
import CoreFoundation
import SnapKit

// MARK: - Delegate

protocol CollectionViewItemDelegate: NSObjectProtocol {
    var preApp: NSRunningApplication? { get }
    func itemDidRequestSelect(_ item: CollectionViewItem)
    func paste(_ item: PasteboardModel)
    func pastePlain(_ item: PasteboardModel)
    func copy(_ item: PasteboardModel)
    func edit(_ item: PasteboardModel)
    func delete(_ item: PasteboardModel, indexPath: IndexPath)
    func assignToChip(_ item: PasteboardModel, chipId: Int)
    func createChip(pinning item: PasteboardModel)
    func preview(_ item: PasteboardModel)
}

// MARK: - CollectionViewItem

final class CollectionViewItem: NSCollectionViewItem {
    weak var delegate: (any CollectionViewItemDelegate)?

    private(set) var item: PasteboardModel?
    private var iconLoadTask: Task<Void, Never>?
    private var isFocused = true
    private var tickCancellable: AnyCancellable?

    isolated deinit {
        if isViewLoaded {
            view.removeFromSuperview()
        }
    }

    // MARK: - Quick Paste

    var quickPasteIndex: Int? {
        didSet {
            updateQuickPasteLabel()
        }
    }

    // MARK: - Head

    private lazy var headView: CardHeadView = .init()

    // MARK: - Selection border

    private lazy var selectionBorderView: AppearanceObservingView = {
        let view = AppearanceObservingView()
        view.wantsLayer = true
        view.layer?.masksToBounds = false
        view.layer?.backgroundColor = nil
        view.layer?.borderWidth = Const.selectionBorderWidth + 0.5
        view.layer?.borderColor = NSColor.clear.cgColor
        view.layer?.cornerRadius = Const.radius + Const.selectionBorderWidth
        view.layer?.cornerCurve = .continuous
        view.onAppearanceChange = { [weak self] in
            self?.updateSelectionBorder()
            self?.updateInfoIconAppearance()
        }
        return view
    }()

    private lazy var contentView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        view.layer?.cornerRadius = Const.radius
        view.layer?.cornerCurve = .continuous
        return view
    }()

    private lazy var cardContentView = CardContentView()
    private lazy var cardBottomView = CardBottomView()

    // MARK: - Badge (Plain Text Indicator + Quick Paste)

    var showPlainTextIndicator: Bool = false {
        didSet {
            infoIconView.isHidden = !showPlainTextIndicator
            updateBadgeVisibility()
        }
    }

    private lazy var badgeEffectView: NSVisualEffectView = {
        let view = NSVisualEffectView()
        view.material = .menu
        view.blendingMode = .withinWindow
        view.state = .active
        view.isHidden = true
        return view
    }()

    private lazy var badgeBgView: BadgeBackgroundView = {
        let view = BadgeBackgroundView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 4
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        view.addSubview(badgeEffectView)
        badgeEffectView.snp.makeConstraints { $0.edges.equalToSuperview() }
        view.isHidden = true
        return view
    }()

    private lazy var badgeStackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = Const.space4
        stack.distribution = .fill
        return stack
    }()

    private lazy var infoIconView: NSImageView = {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "text.justify.leading", accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(textStyle: .footnote)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.isHidden = true
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)
        return icon
    }()

    private lazy var quickPasteLabel: CardLabelView = {
        let label = CardLabelView()
        label.font = .preferredFont(forTextStyle: .callout)
        label.textColor = .labelColor
        label.alignment = .center
        label.isHidden = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    func configure(with model: PasteboardModel, keyword: String = "") {
        item = model
        headView.configure(with: model)
        updateInfoIconAppearance()

        cardContentView.configure(with: model, keyword: keyword)
        cardBottomView.configure(with: model, keyword: keyword)

        tickCancellable = TimeManager.shared.tick
            .sink { [weak self] _ in
                guard let self, let model = item else { return }
                headView.refreshTimestamp(for: model)
            }
    }

    func setFocused(_ focused: Bool) {
        isFocused = focused
        updateSelectionBorder()
    }

    private func updateInfoIconAppearance() {
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            guard let model = item else { return }
            let tintColor: NSColor

            if model.type == .image || model.type == .string {
                badgeBgView.dynamicBackgroundColor = .clear
                badgeBgView.backgroundAlpha = 0
                badgeEffectView.isHidden = false
                tintColor = model.type == .image ? .secondaryLabelColor : model.colors().1
            } else {
                let (base, textColor) = model.colors()
                badgeBgView.dynamicBackgroundColor = base
                badgeBgView.backgroundAlpha = 1
                badgeEffectView.isHidden = true
                tintColor = textColor
            }

            infoIconView.contentTintColor = tintColor
            quickPasteLabel.textColor = tintColor
        }
    }

    private func updateQuickPasteLabel() {
        if let index = quickPasteIndex {
            quickPasteLabel.stringValue = "\(index)"
            quickPasteLabel.isHidden = false
        } else {
            quickPasteLabel.isHidden = true
        }
        updateBadgeVisibility()
    }

    private func updateBadgeVisibility() {
        badgeBgView.isHidden = infoIconView.isHidden && quickPasteLabel.isHidden
    }
}

// MARK: - 生命周期

extension CollectionViewItem {
    override func viewDidLoad() {
        super.viewDidLoad()
        initSubView()
        let doubleClick = CollectionClickGestureRecognizer(target: self, action: #selector(handleDoubleClick))
        doubleClick.numberOfClicksRequired = 2
        doubleClick.delaysPrimaryMouseButtonEvents = false
        view.addGestureRecognizer(doubleClick)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        if #available(macOS 26.0, *) {
            badgeBgView.layer?.cornerRadius = badgeBgView.bounds.height / 2
        }
    }

    override var isSelected: Bool {
        didSet {
            updateSelectionBorder()
        }
    }

    @objc private func handleDoubleClick() {
        handleClipPaste()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        tickCancellable?.cancel()
        tickCancellable = nil
        iconLoadTask?.cancel()
        iconLoadTask = nil
        headView.reset()
        cardContentView.resetContent()
        cardBottomView.reset()
    }

    private func updateSelectionBorder() {
        guard isSelected else {
            selectionBorderView.layer?.borderColor = NSColor.clear.cgColor
            updateShadow()
            return
        }
        let color: NSColor = isFocused
            ? .controlAccentColor
            : .gray.withAlphaComponent(0.5)
        selectionBorderView.effectiveAppearance.performAsCurrentDrawingAppearance {
            selectionBorderView.layer?.borderColor = color.cgColor
        }
        updateShadow()
    }

    private func updateShadow() {
        if isSelected {
            view.shadow = nil
        } else {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.shadowColor.withAlphaComponent(0.1)
            shadow.shadowBlurRadius = 2
            shadow.shadowOffset = CGSize(width: 0, height: -1)
            view.shadow = shadow
        }
    }
}

// MARK: - UI

extension CollectionViewItem {
    func initSubView() {
        view.wantsLayer = true
        view.clipsToBounds = false
        view.layer?.masksToBounds = false
        view.layer?.backgroundColor = .clear

        let contextMenu = NSMenu()
        contextMenu.delegate = self
        view.menu = contextMenu

        view.addSubview(selectionBorderView)
        view.addSubview(contentView)
        contentView.addSubview(headView)
        contentView.addSubview(cardContentView)
        contentView.addSubview(cardBottomView)
        badgeBgView.addSubview(badgeStackView)
        badgeStackView.addArrangedSubview(infoIconView)
        badgeStackView.addArrangedSubview(quickPasteLabel)
        contentView.addSubview(badgeBgView)

        selectionBorderView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(-Const.selectionBorderWidth)
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        headView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Const.hdSize)
        }

        cardContentView.snp.makeConstraints { make in
            make.top.equalTo(headView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        cardBottomView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(Const.bottomSize)
        }

        badgeBgView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Const.space8)
            make.bottom.equalTo(cardBottomView.snp.bottom).inset(Const.space8)
            make.height.equalTo(18)
        }

        badgeStackView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(Const.space6)
        }

        updateShadow()
    }
}

extension CollectionViewItem: UserInterfaceItemIdentifier {}

// MARK: - AppearanceObservingView

private final class AppearanceObservingView: NSView {
    var onAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }
}
