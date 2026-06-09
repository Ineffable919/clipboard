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

    // MARK: - Badge (Plain Text Indicator + Quick Paste)

    var showPlainTextIndicator: Bool = false {
        didSet {
            infoIconView.isHidden = !showPlainTextIndicator
            updateBadgeVisibility()
        }
    }

    private lazy var badgeBgView: BadgeBackgroundView = {
        let view = BadgeBackgroundView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 4.0
        view.layer?.cornerCurve = .continuous
        view.isHidden = true
        return view
    }()

    private lazy var badgeStackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 0
        stack.distribution = .fill
        return stack
    }()

    private lazy var infoIconView: NSImageView = {
        let iv = NSImageView()
        iv.image = NSImage(systemSymbolName: "text.justify.leading", accessibilityDescription: nil)
        iv.symbolConfiguration = NSImage.SymbolConfiguration(textStyle: .callout)
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.isHidden = true
        iv.setContentHuggingPriority(.required, for: .horizontal)
        iv.setContentCompressionResistancePriority(.required, for: .horizontal)
        return iv
    }()

    private lazy var quickPasteLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
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
        let backgroundColor: NSColor
        let backgroundAlpha: CGFloat
        let tintColor: NSColor

        if model.type == .image {
            backgroundColor = .unemphasizedSelectedContentBackgroundColor
            backgroundAlpha = 0.8
            tintColor = .secondaryLabelColor
        } else {
            let (base, textColor) = model.colors()
            backgroundColor = base
            backgroundAlpha = 1.0
            tintColor = textColor
        }

        badgeBgView.dynamicBackgroundColor = backgroundColor
        badgeBgView.backgroundAlpha = backgroundAlpha
        infoIconView.contentTintColor = tintColor
        quickPasteLabel.textColor = tintColor
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
    }

    override var isSelected: Bool {
        didSet {
            updateSelectionBorder()
        }
    }

    override func mouseDown(with event: NSEvent) {
        if event.type == .leftMouseDown, event.clickCount == 2 {
            handleClipPaste()
            return
        }
        super.mouseDown(with: event)
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
            updateShadow()
            return
        }
        let color: NSColor = isFocused
            ? .controlAccentColor
            : .gray.withAlphaComponent(0.5)
        selectionBorderView.layer?.borderColor = color.cgColor
        selectionBorderView.layer?.borderWidth = Const.selectionBorderWidth
        updateShadow()
    }

    private func updateShadow() {
        guard let layer = selectionBorderView.layer else { return }
        if isSelected {
            layer.shadowOpacity = 0
        } else {
            layer.shadowColor = NSColor.shadowColor.withAlphaComponent(0.1).cgColor
            layer.shadowOpacity = 1
            layer.shadowRadius = 2
            layer.shadowOffset = CGSize(width: 0, height: -1)
        }
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

    func handleClipCreateChip() {
        guard let model = item else { return }
        delegate?.createChip(pinning: model)
    }

    func handleClipUnpin() {
        guard let model = item else { return }
        delegate?.assignToChip(model, chipId: -1)
    }

    func handleClipPreview() {
        guard let model = item else { return }
        delegate?.preview(model)
    }

    func handleClipRevealInFinder() {
        guard let paths = item?.cachedFilePaths, !paths.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(paths.map { URL(fileURLWithPath: $0) })
    }

    func handleClipOpenInBrowser() {
        guard let model = item, let url = URL(string: model.plainText) else { return }
        NSWorkspace.shared.open(url)
    }

    func handleClipOpenWithDefaultApp() {
        guard let path = item?.cachedFilePaths?.first else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
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
        badgeBgView.addSubview(badgeStackView)
        badgeStackView.addArrangedSubview(infoIconView)
        badgeStackView.addArrangedSubview(quickPasteLabel)
        contentView.addSubview(badgeBgView)

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

        badgeBgView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Const.space8)
            make.bottom.equalTo(cardBottomView.snp.bottom).inset(Const.space8)
            make.height.equalTo(18)
        }

        badgeStackView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(Const.space2)
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
