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

    override func mouseDown(with event: NSEvent) {
        animateScale(to: 1.05)
        super.mouseDown(with: event)
        animateScale(to: 1.0)
    }

    private func animateScale(to scale: CGFloat) {
        guard let layer else { return }
        let anim = CASpringAnimation(keyPath: "transform.scale")
        anim.toValue = scale
        anim.damping = 12
        anim.initialVelocity = 8
        anim.duration = anim.settlingDuration
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        layer.add(anim, forKey: "scale")
        layer.transform = CATransform3DMakeScale(scale, scale, 1)
    }

    @objc private func handleClick() {
        onTap?()
    }
}
