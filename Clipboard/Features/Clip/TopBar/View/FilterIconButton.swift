//
//  FilterIconButton.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit
import SnapKit

final class FilterIconButton: NSButton {
    var isActive: Bool = false {
        didSet { updateAppearance() }
    }

    var onTap: (() -> Void)?

    init() {
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    private func setup() {
        bezelStyle = .inline
        isBordered = false
        refusesFirstResponder = true

        let symConfig = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        image = NSImage(
            systemSymbolName: "line.3.horizontal.decrease",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(symConfig)

        target = self
        action = #selector(handleClick)

        snp.makeConstraints { make in
            make.width.height.equalTo(28)
        }

        updateAppearance()
    }

    private func updateAppearance() {
        contentTintColor = isActive ? .controlAccentColor : .labelColor
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    @objc private func handleClick() {
        onTap?()
    }
}
