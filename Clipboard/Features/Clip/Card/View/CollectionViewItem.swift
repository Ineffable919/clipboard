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
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .labelColor
        label.alignment = .right
        label.isHidden = true
        return label
    }()

    func configure(with model: PasteboardModel, keyword: String = "") {
        item = model
        headView.configure(with: model)
        updateContentBackground()

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
            handlePaste()
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

extension CollectionViewItem {
    private func makeContextMenu(for model: PasteboardModel) -> NSMenu {
        let menu = NSMenu()

        menu.addItem(pasteItem(for: model))

        if model.pasteboardType.isText() {
            menu.addItem(pastePlainItem())
        }

        menu.addItem(copyItem())
        menu.addItem(.separator())

        if model.pasteboardType.isText() {
            menu.addItem(editItem())
        }

        menu.addItem(deleteItem())
        menu.addItem(.separator())
        menu.addItem(previewItem())

        return menu
    }

    private func pasteItem(for _: PasteboardModel) -> NSMenuItem {
        let title = if let appName = delegate?.preApp?.localizedName, PasteUserDefaults.pasteDirect {
            String(localized: .pasteToApp(appName))
        } else {
            String(localized: .paste)
        }
        let item = NSMenuItem(title: title, action: #selector(handlePaste), keyEquivalent: "\r")
        item.keyEquivalentModifierMask = []
        item.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
        item.target = self
        return item
    }

    private func pastePlainItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: String(localized: .pastePlain),
            action: #selector(handlePastePlain),
            keyEquivalent: "\r"
        )
        item.keyEquivalentModifierMask = .shift
        item.image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: nil)
        item.target = self
        return item
    }

    private func copyItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: String(localized: .copy),
            action: #selector(handleCopy),
            keyEquivalent: "c"
        )
        item.keyEquivalentModifierMask = .command
        item.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        item.target = self
        return item
    }

    private func editItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: String(localized: .edit),
            action: #selector(handleEdit),
            keyEquivalent: "e"
        )
        item.keyEquivalentModifierMask = .command
        item.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)
        item.target = self
        return item
    }

    private func deleteItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: String(localized: .delete),
            action: #selector(handleDelete),
            keyEquivalent: "\u{08}" // backspace
        )
        item.keyEquivalentModifierMask = []
        item.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        item.target = self
        return item
    }

    private func previewItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: String(localized: .preview),
            action: #selector(handlePreview),
            keyEquivalent: " "
        )
        item.keyEquivalentModifierMask = []
        item.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)
        item.target = self
        return item
    }

    @objc private func handlePaste() {
        guard let model = item else { return }
        delegate?.paste(model)
    }

    @objc private func handlePastePlain() {
        guard let model = item else { return }
        delegate?.pastePlain(model)
    }

    @objc private func handleCopy() {
        guard let model = item else { return }
        delegate?.copy(model)
    }

    @objc private func handleEdit() {
        guard let model = item else { return }
        delegate?.edit(model)
    }

    @objc private func handleDelete() {
        guard let model = item, let indexPath = collectionView?.indexPath(for: self) else { return }
        delegate?.delete(model, indexPath: indexPath)
    }

    @objc private func handlePreview() {
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
        contentView.addSubview(quickPasteLabel)

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
            make.trailing.equalToSuperview().inset(Const.space6)
            make.bottom.equalToSuperview().inset(Const.space4)
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
        for item in makeContextMenu(for: model).items {
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
