//
//  JSONToolbarView.swift
//  Clipboard
//

import AppKit
import SnapKit

final class JSONToolbarView: NSView {
    var onAction: ((JSONToolAction) -> Void)?
    var onIndentationChange: ((JSONIndentation) -> Void)?

    private(set) var indentation = JSONIndentation.four

    private lazy var formatButton = makeButton(
        title: String(localized: .jsonFormat),
        action: #selector(formatJSON)
    )
    private lazy var compactButton = makeButton(
        title: String(localized: .jsonCompact),
        action: #selector(compactJSON)
    )
    private lazy var indentationButton = makeIndentationButton()
    private lazy var escapeButton = makeMenuButton(
        title: String(localized: .jsonEscape),
        items: [
            (String(localized: .jsonRemoveEscapes), #selector(removeEscapes), 0),
            (String(localized: .jsonAddEscapes), #selector(addEscapes), 0),
        ]
    )
    private lazy var unicodeButton = makeMenuButton(
        title: String(localized: .jsonUnicode),
        items: [
            (String(localized: .jsonDecodeUnicode), #selector(decodeUnicode), 0),
            (String(localized: .jsonEncodeUnicode), #selector(encodeUnicode), 0),
        ]
    )
    private lazy var sortButton = makeMenuButton(
        title: String(localized: .jsonSortKeys),
        items: [
            (String(localized: .jsonSortAscending), #selector(sortAscending), 0),
            (String(localized: .jsonSortDescending), #selector(sortDescending), 0),
        ]
    )
    private lazy var namingButton = makeNamingButton()

    private lazy var stack: NSStackView = {
        let stack = NSStackView(views: [
            formatButton,
            indentationButton,
            compactButton,
            escapeButton,
            unicodeButton,
            sortButton,
            namingButton,
        ])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = Const.space10
        return stack
    }()

    override var intrinsicContentSize: NSSize {
        stack.fittingSize
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func setEnabled(_ enabled: Bool) {
        for view in stack.arrangedSubviews {
            (view as? NSControl)?.isEnabled = enabled
        }
    }

    private func setup() {
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func makeButton(title: String, action: Selector) -> JSONToolbarButton {
        let button = JSONToolbarButton(title: title)
        button.target = self
        button.action = action
        return button
    }

    private func makeIndentationButton() -> JSONToolbarButton {
        let button = JSONToolbarButton(
            title: indentationTitle(for: indentation),
            showsMenuIndicator: true
        )
        let menu = NSMenu()
        for option in JSONIndentation.allCases {
            let item = NSMenuItem(
                title: indentationTitle(for: option),
                action: #selector(changeIndentation(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = option.rawValue
            item.state = option == indentation ? .on : .off
            menu.addItem(item)
        }
        button.popupMenu = menu
        button.target = self
        button.action = #selector(showMenu(_:))
        return button
    }

    private func makeMenuButton(
        title: String,
        items: [(String, Selector, Int)]
    ) -> JSONToolbarButton {
        let button = JSONToolbarButton(title: title, showsMenuIndicator: true)
        let menu = NSMenu()
        for (itemTitle, action, tag) in items {
            let item = NSMenuItem(
                title: itemTitle,
                action: action,
                keyEquivalent: ""
            )
            item.target = self
            item.tag = tag
            menu.addItem(item)
        }
        button.popupMenu = menu
        button.target = self
        button.action = #selector(showMenu(_:))
        return button
    }

    private func makeNamingButton() -> JSONToolbarButton {
        let items: [(String, Selector, Int)] = JSONKeyNaming.allCases.map { naming in
            let title = switch naming {
            case .space: String(localized: .jsonKeySpace)
            case .title: String(localized: .jsonKeyTitle)
            case .kebab: String(localized: .jsonKeyKebab)
            case .screamingSnake: String(localized: .jsonKeyScreamingSnake)
            case .pascal: String(localized: .jsonKeyPascal)
            case .camel: String(localized: .jsonKeyCamel)
            case .snake: String(localized: .jsonKeySnake)
            }
            return (title, #selector(renameKeys(_:)), naming.rawValue)
        }
        return makeMenuButton(
            title: String(localized: .jsonRenameKeys),
            items: items
        )
    }

    private func indentationTitle(for option: JSONIndentation) -> String {
        option == .none
            ? String(localized: .jsonIndentNone)
            : String(localized: .jsonIndentSpaces(option.rawValue))
    }

    @objc private func showMenu(_ sender: JSONToolbarButton) {
        let bottomY = sender.isFlipped
            ? sender.bounds.maxY + Const.space8
            : sender.bounds.minY - Const.space8
        sender.popupMenu?.popUp(
            positioning: nil,
            at: NSPoint(x: sender.bounds.minX, y: bottomY),
            in: sender
        )
    }

    @objc private func changeIndentation(_ sender: NSMenuItem) {
        guard let selected = JSONIndentation(rawValue: sender.tag) else { return }
        indentation = selected
        indentationButton.title = indentationTitle(for: selected)
        indentationButton.popupMenu?.items.forEach { item in
            item.state = item.tag == selected.rawValue ? .on : .off
        }
        onIndentationChange?(selected)
    }

    @objc private func formatJSON() {
        onAction?(.format(indentation))
    }

    @objc private func compactJSON() {
        onAction?(.compact)
    }

    @objc private func removeEscapes() {
        onAction?(.removeEscapes)
    }

    @objc private func addEscapes() {
        onAction?(.addEscapes)
    }

    @objc private func decodeUnicode() {
        onAction?(.decodeUnicode)
    }

    @objc private func encodeUnicode() {
        onAction?(.encodeUnicode)
    }

    @objc private func sortAscending() {
        onAction?(.sortKeys(ascending: true, indentation: indentation))
    }

    @objc private func sortDescending() {
        onAction?(.sortKeys(ascending: false, indentation: indentation))
    }

    @objc private func renameKeys(_ sender: NSMenuItem) {
        guard let naming = JSONKeyNaming(rawValue: sender.tag) else { return }
        onAction?(.renameKeys(naming, indentation: indentation))
    }
}
