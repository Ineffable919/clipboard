//
//  ChipButton.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit
import SnapKit
import SwiftUI

final class ChipButton: NSView {
    // MARK: - Config

    struct Config {
        let chip: CategoryChip
        var isSelected: Bool
        var dotMode: Bool = false
        var action: () -> Void
    }

    // MARK: - Subviews

    private let backgroundLayer = CALayer()
    private let iconImageView = NSImageView()
    private let dotView = NSView()
    private let label = NSTextField(labelWithString: "")
    private let stack = NSStackView()

    // MARK: - State

    private var config: Config
    private var isHovering = false

    var isSelected: Bool {
        get { config.isSelected }
        set {
            config.isSelected = newValue
            updateAppearance(animated: true)
        }
    }

    // MARK: - Init

    init(config: Config) {
        self.config = config
        super.init(frame: .zero)
        setup()
        updateContent()
        updateAppearance(animated: false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true

        backgroundLayer.cornerRadius = Const.radius
        backgroundLayer.masksToBounds = true
        layer?.addSublayer(backgroundLayer)

        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )
        label.setContentHuggingPriority(.required, for: .horizontal)

        stack.orientation = .horizontal
        stack.spacing = Const.space6
        stack.alignment = .centerY
        addSubview(stack)

        let hPad: CGFloat = config.dotMode ? Const.space6 : Const.space10
        stack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(hPad)
            make.trailing.equalToSuperview().offset(-hPad)
            make.top.equalToSuperview().offset(Const.space6)
            make.bottom.equalToSuperview().offset(-Const.space6)
        }

        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [
                    .mouseEnteredAndExited, .activeAlways, .inVisibleRect,
                ],
                owner: self,
                userInfo: nil
            )
        )
        addGestureRecognizer(
            NSClickGestureRecognizer(
                target: self,
                action: #selector(handleClick)
            )
        )
    }

    private func updateContent() {
        for arrangedSubview in stack.arrangedSubviews {
            stack.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }

        if config.dotMode {
            if config.chip.isSystem {
                iconImageView.image = NSImage(
                    systemSymbolName:
                    "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    accessibilityDescription: nil
                )?.withSymbolConfiguration(
                    .init(pointSize: 12, weight: .medium)
                )
                iconImageView.imageScaling = .scaleProportionallyDown
                iconImageView.snp.remakeConstraints { make in
                    make.width.height.equalTo(16)
                }
                stack.addArrangedSubview(iconImageView)
            } else {
                let container = NSView()
                container.wantsLayer = true
                container.snp.makeConstraints { make in
                    make.width.height.equalTo(16)
                }
                dotView.wantsLayer = true
                dotView.layer?.cornerRadius = 6
                dotView.layer?.backgroundColor =
                    NSColor(config.chip.color).cgColor
                container.addSubview(dotView)
                dotView.snp.makeConstraints { make in
                    make.width.height.equalTo(12)
                    make.center.equalToSuperview()
                }
                stack.addArrangedSubview(container)
            }
        } else {
            if config.chip.id == -1 {
                iconImageView.image = NSImage(
                    systemSymbolName:
                    "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    accessibilityDescription: nil
                )?.withSymbolConfiguration(
                    .init(pointSize: 16, weight: .medium)
                )
                iconImageView.imageScaling = .scaleProportionallyDown
                iconImageView.snp.remakeConstraints { make in
                    make.width.height.equalTo(16)
                }
                stack.addArrangedSubview(iconImageView)
            } else {
                let container = NSView()
                container.wantsLayer = true
                container.snp.makeConstraints { make in
                    make.width.height.equalTo(16)
                }
                dotView.wantsLayer = true
                dotView.layer?.cornerRadius = 6
                dotView.layer?.backgroundColor =
                    NSColor(config.chip.color).cgColor
                container.addSubview(dotView)
                dotView.snp.makeConstraints { make in
                    make.width.height.equalTo(12)
                    make.center.equalToSuperview()
                }
                stack.addArrangedSubview(container)
            }
            label.stringValue = config.chip.name
            stack.addArrangedSubview(label)
        }
    }

    // MARK: - Appearance

    private func updateAppearance(animated: Bool) {
        let isDark =
            effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let bgColor: NSColor = if config.dotMode {
            isHovering
                ? (isDark
                    ? NSColor(Const.hoverDarkColor)
                    : NSColor(Const.hoverLightColorFrosted))
                : .clear
        } else if config.isSelected {
            isDark
                ? NSColor(Const.chooseDarkColor)
                : NSColor(Const.chooseLightColorFrosted)
        } else if isHovering {
            isDark
                ? NSColor(Const.hoverDarkColor)
                : NSColor(Const.hoverLightColorFrosted)
        } else {
            .clear
        }

        label.textColor = isDark ? .white : .black
        iconImageView.contentTintColor = isDark ? .white : .black

        let apply = { self.backgroundLayer.backgroundColor = bgColor.cgColor }

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                ctx.allowsImplicitAnimation = true
                apply()
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            apply()
            CATransaction.commit()
        }
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance(animated: false)
    }

    // MARK: - Mouse

    override func mouseEntered(with _: NSEvent) {
        isHovering = true
        updateAppearance(animated: true)
    }

    override func mouseExited(with _: NSEvent) {
        isHovering = false
        updateAppearance(animated: true)
    }

    // MARK: - Action

    @objc private func handleClick() {
        config.action()
    }
}
