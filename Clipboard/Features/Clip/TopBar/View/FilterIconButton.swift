//
//  FilterIconButton.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit
import SnapKit
import SwiftUI

final class FilterIconButton: NSView {
    // MARK: - Properties

    private let backgroundLayer = CALayer()
    private let imageView = NSImageView()

    var isActive: Bool = false {
        didSet { updateAppearance(animated: false) }
    }

    var action: (() -> Void)?

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        setup()
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

        let symConfig = NSImage.SymbolConfiguration(
            pointSize: 15,
            weight: .regular
        )
        imageView.image = NSImage(
            systemSymbolName: "line.3.horizontal.decrease",
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
        imageView.contentTintColor = .labelColor

        let bgColor: NSColor = .clear

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

    // MARK: - Action

    @objc private func handleClick() {
        action?()
    }
}
