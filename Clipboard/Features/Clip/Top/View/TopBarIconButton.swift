//
//  TopBarIconButton.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit
import SnapKit
import SwiftUI

final class TopBarIconButton: NSView {
    // MARK: - Properties

    private let backgroundLayer = CALayer()
    private let imageView = NSImageView()
    private let badgeDot = NSView()
    private var isHovering = false

    var isActive: Bool = false {
        didSet { updateAppearance(animated: false) }
    }

    var showBadge: Bool = false {
        didSet {
            guard showBadge != oldValue else { return }
            badgeDot.isHidden = !showBadge
        }
    }

    var action: (() -> Void)?

    // MARK: - Init

    init(symbolName: String, pointSize: CGFloat = 15) {
        super.init(frame: .zero)
        setup(symbolName: symbolName, pointSize: pointSize)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Setup

    private func setup(symbolName: String, pointSize: CGFloat) {
        wantsLayer = true

        backgroundLayer.cornerRadius = Const.radius
        backgroundLayer.masksToBounds = true
        layer?.addSublayer(backgroundLayer)

        let symConfig = NSImage.SymbolConfiguration(
            pointSize: pointSize,
            weight: .regular
        )
        imageView.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(symConfig)
        imageView.imageScaling = .scaleProportionallyDown
        addSubview(imageView)

        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        snp.makeConstraints { make in
            make.width.height.equalTo(28)
        }

        badgeDot.wantsLayer = true
        badgeDot.layer?.cornerRadius = 3.5
        badgeDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        badgeDot.isHidden = true
        addSubview(badgeDot)
        badgeDot.snp.makeConstraints { make in
            make.width.height.equalTo(7)
            make.top.equalToSuperview().offset(-2)
            make.trailing.equalToSuperview().offset(2)
        }

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

        updateAppearance(animated: false)
    }

    // MARK: - Appearance

    private func updateAppearance(animated: Bool) {
        let isDark =
            effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        imageView.contentTintColor = .labelColor

        let bgColor: NSColor =
            isHovering
                ? (isDark
                    ? .quinaryLabelColor
                    : .labelColor.withAlphaComponent(0.06))
                : .clear

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.1
                ctx.allowsImplicitAnimation = true
                backgroundLayer.backgroundColor = bgColor.cgColor
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            backgroundLayer.backgroundColor = bgColor.cgColor
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
        action?()
    }
}
