//
//  FilterIconButton.swift
//  Clipboard
//
//  Created by crown on 2026/4/9
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

    // 鼠标按下即触发，不走按钮的跟踪流程；辅助功能的按下仍经 performClick 发送 action
    override func mouseDown(with _: NSEvent) {
        guard isEnabled else { return }
        animateClick()
        onTap?()
    }

    private func animateClick() {
        guard let layer else { return }

        let currentScale = layer.presentation()?.transform.m11 ?? layer.transform.m11
        layer.removeAnimation(forKey: "scale")
        layer.transform = CATransform3DIdentity

        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            return
        }

        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.values = [currentScale, 1.05, 1.0]
        animation.keyTimes = [0, 0.375, 1]
        animation.duration = 0.16
        animation.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeOut)
        ]
        layer.add(animation, forKey: "scale")
    }

    @objc private func handleClick() {
        onTap?()
    }
}
