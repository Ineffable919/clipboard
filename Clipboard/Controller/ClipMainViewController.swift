//
//  ClipMainViewController.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import SwiftUI

final class ClipMainViewController: NSViewController {
    private let defaultHeight: CGFloat = 330.0
    private let showDuration: CFTimeInterval = 0.15
    private let hideDuration: CFTimeInterval = 0.24
    private(set) var isPresented: Bool = false

    private let slideContainer: NSView = {
        if #available(macOS 26, *) {
            let v = NSView()
            v.translatesAutoresizingMaskIntoConstraints = false
            v.wantsLayer = true
            return v
        } else {
            let v = NSVisualEffectView()
            v.translatesAutoresizingMaskIntoConstraints = false
            v.wantsLayer = true
            v.material = .sidebar
            v.blendingMode = .behindWindow
            v.state = .active
            v.isEmphasized = true
            return v
        }
    }()

    private let hostingView: NSHostingView<ContentView> = {
        let v = NSHostingView(rootView: ContentView())
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
        view.layer?.masksToBounds = true

        view.addSubview(slideContainer)
        NSLayoutConstraint.activate([
            slideContainer.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
            ),
            slideContainer.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
            ),
            slideContainer.topAnchor.constraint(equalTo: view.topAnchor),
            slideContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        DispatchQueue.main.async {
            self.view.layoutSubtreeIfNeeded()
            let h = max(self.view.bounds.height, self.defaultHeight)
            self.slideContainer.layer?.transform = CATransform3DMakeTranslation(
                0,
                -h,
                0,
            )
        }
    }

    func setPresented(
        _ presented: Bool,
        animated: Bool,
        completion: (() -> Void)? = nil,
    ) {
        guard presented != isPresented else {
            completion?()
            return
        }

        if presented, !isPresented, hostingView.superview == nil {
            slideContainer.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(
                    equalTo: slideContainer.leadingAnchor,
                ),
                hostingView.trailingAnchor.constraint(
                    equalTo: slideContainer.trailingAnchor,
                ),
                hostingView.topAnchor.constraint(
                    equalTo: slideContainer.topAnchor,
                ),
                hostingView.bottomAnchor.constraint(
                    equalTo: slideContainer.bottomAnchor,
                ),
            ])
        }

        isPresented = presented
        animateSlide(
            presented: presented,
            duration: animated ? (presented ? showDuration : hideDuration) : 0,
            completion: completion,
        )
    }

    private func animateSlide(
        presented: Bool,
        duration: CFTimeInterval,
        completion: (() -> Void)?,
    ) {
        guard let layer = slideContainer.layer else {
            completion?()
            return
        }

        view.layoutSubtreeIfNeeded()
        let h = max(view.bounds.height, defaultHeight)

        let from = layer.presentation()?.transform ?? layer.transform
        let to = CATransform3DMakeTranslation(0, presented ? 0 : -h, 0)

        layer.removeAnimation(forKey: "slide")

        if duration <= 0 {
            layer.transform = to
            completion?()
            return
        }

        let anim = CABasicAnimation(keyPath: "transform")
        anim.fromValue = from
        anim.toValue = to
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false

        class AnimDelegate: NSObject, CAAnimationDelegate {
            let onStop: () -> Void
            init(_ onStop: @escaping () -> Void) { self.onStop = onStop }
            func animationDidStop(_: CAAnimation, finished flag: Bool) {
                if flag { onStop() }
            }
        }

        var delegateRef: AnimDelegate!
        delegateRef = AnimDelegate { [weak self] in
            layer.transform = to
            if let strongSelf = self,
               strongSelf.currentAnimDelegate === delegateRef
            {
                strongSelf.currentAnimDelegate = nil
            }
            completion?()
        }

        currentAnimDelegate = delegateRef
        anim.delegate = delegateRef

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.add(anim, forKey: "slide")
        layer.transform = to
        CATransaction.commit()
    }
}
