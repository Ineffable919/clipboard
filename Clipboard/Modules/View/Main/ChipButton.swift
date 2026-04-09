//
//  ChipButton.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit
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
    private let dotLayer = CALayer()
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
    required init?(coder: NSCoder) { fatalError() }

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
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let hPad = config.dotMode ? Const.space6 : Const.space10
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: hPad
            ),
            stack.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -hPad
            ),
            stack.topAnchor.constraint(
                equalTo: topAnchor,
                constant: Const.space6
            ),
            stack.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -Const.space6
            ),
        ])

        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)

        let click = NSClickGestureRecognizer(
            target: self,
            action: #selector(handleClick)
        )
        addGestureRecognizer(click)
    }

    private func updateContent() {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        if config.dotMode {
            if config.chip.isSystem {
                let symConfig = NSImage.SymbolConfiguration(
                    pointSize: 12,
                    weight: .medium
                )
                iconImageView.image = NSImage(
                    systemSymbolName:
                        "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    accessibilityDescription: nil
                )?.withSymbolConfiguration(symConfig)
                iconImageView.imageScaling = .scaleProportionallyDown
                iconImageView.translatesAutoresizingMaskIntoConstraints = false
                iconImageView.widthAnchor.constraint(equalToConstant: 14)
                    .isActive = true
                iconImageView.heightAnchor.constraint(equalToConstant: 14)
                    .isActive = true
                stack.addArrangedSubview(iconImageView)
            } else {
                let dotSize: CGFloat = 12
                let container = NSView()
                container.wantsLayer = true
                container.translatesAutoresizingMaskIntoConstraints = false
                container.widthAnchor.constraint(equalToConstant: dotSize)
                    .isActive = true
                container.heightAnchor.constraint(equalToConstant: dotSize)
                    .isActive = true
                dotLayer.frame = CGRect(
                    origin: .zero,
                    size: CGSize(width: dotSize, height: dotSize)
                )
                dotLayer.cornerRadius = dotSize / 2
                dotLayer.backgroundColor = NSColor(config.chip.color).cgColor
                container.layer?.addSublayer(dotLayer)
                stack.addArrangedSubview(container)
            }
        } else {
            if config.chip.id == -1 {
                let symConfig = NSImage.SymbolConfiguration(
                    pointSize: 16,
                    weight: .medium
                )
                iconImageView.image = NSImage(
                    systemSymbolName:
                        "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    accessibilityDescription: nil
                )?.withSymbolConfiguration(symConfig)
                iconImageView.imageScaling = .scaleProportionallyDown
                iconImageView.translatesAutoresizingMaskIntoConstraints = false
                iconImageView.widthAnchor.constraint(equalToConstant: 14)
                    .isActive = true
                iconImageView.heightAnchor.constraint(equalToConstant: 14)
                    .isActive = true
                stack.addArrangedSubview(iconImageView)
            } else {
                let dotSize: CGFloat = 12
                let container = NSView()
                container.wantsLayer = true
                container.translatesAutoresizingMaskIntoConstraints = false
                container.widthAnchor.constraint(equalToConstant: dotSize)
                    .isActive = true
                container.heightAnchor.constraint(equalToConstant: dotSize)
                    .isActive = true
                dotLayer.frame = CGRect(
                    origin: .zero,
                    size: CGSize(width: dotSize, height: dotSize)
                )
                dotLayer.cornerRadius = dotSize / 2
                dotLayer.backgroundColor = NSColor(config.chip.color).cgColor
                container.layer?.addSublayer(dotLayer)
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

        let bgColor: NSColor

        if config.dotMode {
            if isHovering {
                bgColor = isDark
                    ? NSColor(Const.hoverDarkColor)
                    : NSColor(Const.hoverLightColorFrosted)
            } else {
                bgColor = .clear
            }
        } else if config.isSelected {
            bgColor =
                isDark
                ? NSColor(Const.chooseDarkColor)
                : NSColor(Const.chooseLightColorFrosted)
        } else if isHovering {
            bgColor =
                isDark
                ? NSColor(Const.hoverDarkColor)
                : NSColor(Const.hoverLightColorFrosted)
        } else {
            bgColor = .clear
        }

        label.textColor = .labelColor
        iconImageView.contentTintColor = .labelColor

        let apply = {
            self.backgroundLayer.backgroundColor = bgColor.cgColor
        }

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

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateAppearance(animated: true)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance(animated: true)
    }

    // MARK: - Action

    @objc private func handleClick() {
        config.action()
    }
}
