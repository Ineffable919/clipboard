//
//  ClipFloatingViewController.swift
//  Clipboard
//
//  Created by crown on 2025/1/14.
//

import AppKit
import SwiftUI

final class ClipFloatingViewController: NSViewController {
    private let showDuration: CFTimeInterval = 0.2
    private let hideDuration: CFTimeInterval = 0.15
    private(set) var isPresented: Bool = false

    private let fadeContainer: NSView = {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.clear.cgColor
        v.layer?.opacity = 0
        return v
    }()

    var env = AppEnvironment()

    private lazy var hostingView: NSHostingView<some View> = {
        let contentView = FloatingView()
            .environment(env)
        let v = NSHostingView(rootView: contentView)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.clear.cgColor
        return v
    }()

    private var currentAnimDelegate: CAAnimationDelegate?

    override func loadView() { view = NSView() }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        view.addSubview(fadeContainer)
        NSLayoutConstraint.activate([
            fadeContainer.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            fadeContainer.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            fadeContainer.topAnchor.constraint(equalTo: view.topAnchor),
            fadeContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func setPresented(
        _ presented: Bool,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        guard presented != isPresented else {
            completion?()
            return
        }

        if presented, !isPresented, hostingView.superview == nil {
            fadeContainer.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(
                    equalTo: fadeContainer.leadingAnchor
                ),
                hostingView.trailingAnchor.constraint(
                    equalTo: fadeContainer.trailingAnchor
                ),
                hostingView.topAnchor.constraint(
                    equalTo: fadeContainer.topAnchor
                ),
                hostingView.bottomAnchor.constraint(
                    equalTo: fadeContainer.bottomAnchor
                ),
            ])
        }

        isPresented = presented
        animateFade(
            presented: presented,
            duration: animated ? (presented ? showDuration : hideDuration) : 0,
            completion: completion
        )
    }

    private func animateFade(
        presented: Bool,
        duration: CFTimeInterval,
        completion: (() -> Void)?
    ) {
        guard let layer = fadeContainer.layer else {
            completion?()
            return
        }

        let from = layer.presentation()?.opacity ?? layer.opacity
        let to: Float = presented ? 1.0 : 0.0

        layer.removeAnimation(forKey: "fade")
        currentAnimDelegate = nil

        if duration <= 0 {
            layer.opacity = to
            completion?()
            return
        }

        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = from
        anim.toValue = to
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false

        class AnimDelegate: NSObject, CAAnimationDelegate {
            var onStop: (() -> Void)?
            init(_ onStop: @escaping () -> Void) { self.onStop = onStop }
            func animationDidStop(_: CAAnimation, finished flag: Bool) {
                if flag { onStop?() }
                onStop = nil
            }
        }

        let delegate = AnimDelegate { [weak self] in
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.opacity = to
            CATransaction.commit()
            layer.removeAnimation(forKey: "fade")
            self?.currentAnimDelegate = nil
            completion?()
        }

        currentAnimDelegate = delegate
        anim.delegate = delegate

        layer.add(anim, forKey: "fade")
    }
}
