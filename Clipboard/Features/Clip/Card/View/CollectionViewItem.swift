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
    func preview(_ item: PasteboardModel)
}

// MARK: - CollectionViewItem

final class CollectionViewItem: NSCollectionViewItem {
    weak var delegate: (any CollectionViewItemDelegate)?

    private var item: PasteboardModel?
    private var iconLoadTask: Task<Void, Never>?
    private var isFocused = true
    private var tickCancellable: AnyCancellable?

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
        view.layer?.backgroundColor = .clear
        view.layer?.cornerRadius = Const.radius + Const.selectionBorderWidth
        view.layer?.cornerCurve = .continuous
        view.layer?.borderWidth = 0
        view.onAppearanceChange = { [weak self] in
            self?.updateSelectionBorder()
            self?.updateShadow()
            self?.updateInfoIconAppearance()
        }
        return view
    }()

    private lazy var contentView: DynamicBackgroundView = {
        let view = DynamicBackgroundView()
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        view.layer?.cornerRadius = Const.radius
        view.layer?.cornerCurve = .continuous
        return view
    }()

    private lazy var cardContentView = CardContentView()
    private lazy var cardBottomView = CardBottomView()

    // MARK: - Quick Paste Label

    private lazy var quickPasteLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        label.textColor = .labelColor
        label.alignment = .center
        label.isHidden = true
        return label
    }()

    // MARK: - Plain Text Indicator

    var showPlainTextIndicator: Bool = false {
        didSet {
            infoIconBackgroundView.isHidden = !showPlainTextIndicator
            updateInfoIconTrailingConstraint()
        }
    }

    private lazy var infoIconBackgroundView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 4.0
        view.layer?.cornerCurve = .continuous
        view.isHidden = true
        return view
    }()

    private lazy var infoIconView: NSImageView = {
        let iv = NSImageView()
        iv.image = NSImage(systemSymbolName: "text.justify.leading", accessibilityDescription: nil)
        iv.symbolConfiguration = NSImage.SymbolConfiguration(textStyle: .callout)
        iv.imageScaling = .scaleProportionallyUpOrDown
        return iv
    }()

    func configure(with model: PasteboardModel, keyword: String = "") {
        item = model
        headView.configure(with: model)
        updateContentBackground()
        updateInfoIconAppearance()

        cardContentView.configure(with: model, keyword: keyword)
        cardBottomView.configure(with: model, keyword: keyword)

        tickCancellable = TimeManager.shared.tick
            .sink { [weak self] _ in
                guard let self, let model = item else { return }
                headView.refreshTimestamp(for: model)
            }
    }

    private func updateContentBackground() {
        guard let model = item else { return }
        if model.type == .color || (model.type == .rich && model.hasBgColor),
           let bgColor = model.cachedBackgroundColor
        {
            contentView.dynamicBackgroundColor = bgColor
        } else {
            contentView.dynamicBackgroundColor = NSColor.textBackgroundColor
        }
    }

    func setFocused(_ focused: Bool) {
        isFocused = focused
        updateSelectionBorder()
    }

    private func updateInfoIconAppearance() {
        guard let model = item else { return }
        var backgroundCGColor: CGColor = NSColor.clear.cgColor
        var tintColor: NSColor = .labelColor

        infoIconBackgroundView.effectiveAppearance.performAsCurrentDrawingAppearance {
            if model.type == .image {
                backgroundCGColor = NSColor.unemphasizedSelectedContentBackgroundColor
                    .withAlphaComponent(0.8).cgColor
                tintColor = .secondaryLabelColor
            } else {
                let (base, textColor) = model.colors()
                backgroundCGColor = base.cgColor
                tintColor = textColor
            }
        }

        infoIconBackgroundView.layer?.backgroundColor = backgroundCGColor
        infoIconView.contentTintColor = tintColor
    }

    private func updateQuickPasteLabel() {
        if let index = quickPasteIndex {
            quickPasteLabel.stringValue = "\(index)"
            quickPasteLabel.isHidden = false

            if let model = item {
                let (_, textColor) = model.colors()
                quickPasteLabel.textColor = textColor
            }
        } else {
            quickPasteLabel.isHidden = true
        }
        updateInfoIconTrailingConstraint()
    }

    private func updateInfoIconTrailingConstraint() {
        infoIconBackgroundView.snp.remakeConstraints { make in
            if quickPasteLabel.isHidden {
                make.trailing.equalToSuperview().inset(Const.space8)
            } else {
                make.trailing.equalTo(quickPasteLabel.snp.leading)
            }
            make.bottom.equalTo(cardBottomView.snp.bottom).inset(Const.space8)
        }
    }
}

// MARK: - 生命周期

extension CollectionViewItem {
    override func viewDidLoad() {
        super.viewDidLoad()
        initSubView()
    }

    override var isSelected: Bool {
        didSet {
            updateSelectionBorder()
        }
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if event.type == .leftMouseDown, event.clickCount == 2 {
            handleClipPaste()
        }
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
            selectionBorderView.layer?.borderWidth = 0
            return
        }
        let color: NSColor = isFocused
            ? .controlAccentColor
            : .gray.withAlphaComponent(0.5)
        selectionBorderView.layer?.borderColor = color.cgColor
        selectionBorderView.layer?.borderWidth = Const.selectionBorderWidth
    }

    private func updateShadow() {
        guard let layer = selectionBorderView.layer else { return }
        layer.shadowColor = NSColor.shadowColor.withAlphaComponent(0.1).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 2
        layer.shadowOffset = CGSize(width: 0, height: -1)
    }
}

// MARK: - Context Menu

extension CollectionViewItem: ClipItemMenuActionable {
    private var pasteMenuTitle: String {
        if let appName = delegate?.preApp?.localizedName, PasteUserDefaults.pasteDirect {
            String(localized: .pasteToApp(appName))
        } else {
            String(localized: .paste)
        }
    }

    func handleClipPaste() {
        guard let model = item else { return }
        delegate?.paste(model)
    }

    func handleClipPastePlain() {
        guard let model = item else { return }
        delegate?.pastePlain(model)
    }

    func handleClipCopy() {
        guard let model = item else { return }
        delegate?.copy(model)
    }

    func handleClipEdit() {
        guard let model = item else { return }
        delegate?.edit(model)
    }

    func handleClipDelete() {
        guard let model = item, let indexPath = collectionView?.indexPath(for: self) else { return }
        delegate?.delete(model, indexPath: indexPath)
    }

    func handleClipAssignToChip(_ sender: NSMenuItem) {
        guard let model = item, model.group != sender.tag else { return }
        delegate?.assignToChip(model, chipId: sender.tag)
    }

    func handleClipUnpin() {
        guard let model = item else { return }
        delegate?.assignToChip(model, chipId: -1)
    }

    func handleClipPreview() {
        guard let model = item else { return }
        delegate?.preview(model)
    }
}

// MARK: - UI

extension CollectionViewItem {
    func initSubView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear

        let contextMenu = NSMenu()
        contextMenu.delegate = self
        view.menu = contextMenu

        view.addSubview(selectionBorderView)
        selectionBorderView.addSubview(contentView)
        contentView.addSubview(headView)
        contentView.addSubview(cardContentView)
        contentView.addSubview(cardBottomView)
        infoIconBackgroundView.addSubview(infoIconView)
        contentView.addSubview(quickPasteLabel)
        contentView.addSubview(infoIconBackgroundView)

        selectionBorderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Const.selectionBorderWidth)
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

        quickPasteLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Const.space8)
            make.bottom.equalTo(cardBottomView.snp.bottom).inset(Const.space8)
        }

        infoIconBackgroundView.snp.makeConstraints { make in
            make.trailing.equalTo(quickPasteLabel.snp.leading)
            make.bottom.equalTo(cardBottomView.snp.bottom).inset(Const.space8)
        }

        infoIconView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(4)
            make.leading.trailing.equalToSuperview().inset(Const.space4)
        }

        updateShadow()
    }
}

extension CollectionViewItem: UserInterfaceItemIdentifier {}

// MARK: - NSMenuDelegate

extension CollectionViewItem: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let model = item else { return }
        delegate?.itemDidRequestSelect(self)
        for item in buildClipItemMenu(for: model, pasteTitle: pasteMenuTitle).items {
            menu.addItem(item)
        }
    }
}

// MARK: - AppearanceObservingView

private final class AppearanceObservingView: NSView {
    var onAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }
}
