//
//  BackgroundEffectController.swift
//  Clipboard
//
//  统一管理窗口的背景效果视图（NSGlassEffectView / NSVisualEffectView）
//  以及随用户偏好变化的切换/重建逻辑。
//

import AppKit
import Combine
import SnapKit

@MainActor
final class BackgroundEffectController {
    private(set) var effectView: NSView
    let contentContainer: NSView

    private weak var host: NSView?
    private let presentationView: NSView?
    private let cornerRadius: CGFloat
    private let innerPadding: CGFloat

    private var lastBackgroundType: Int = PasteUserDefaults.backgroundType
    private var cancellables = Set<AnyCancellable>()
    private var presentationMask: CALayer?
    private var slideGeneration = 0

    init(cornerRadius: CGFloat, innerPadding: CGFloat = 0, slides: Bool = false) {
        self.cornerRadius = cornerRadius
        self.innerPadding = innerPadding

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        if #available(macOS 26.0, *) {
            container.layer?.cornerRadius = cornerRadius
        }
        container.layer?.masksToBounds = true
        contentContainer = container

        if slides {
            if #available(macOS 15.0, *) {
                let presentation = NSView()
                presentation.wantsLayer = true
                presentation.layer?.backgroundColor = NSColor.clear.cgColor
                presentationView = presentation
            } else {
                presentationView = nil
            }
        } else {
            presentationView = nil
        }

        effectView = Self.buildEffectView(
            cornerRadius: cornerRadius,
            contentContainer: slides ? nil : container
        )

        observeSettings()
    }

    func install(in host: NSView) {
        self.host = host
        attach()
    }

    func prepareSlidePresentation(initiallyHidden: Bool) -> Bool {
        let presentationView = presentationView ?? effectView
        guard let effectLayer = presentationView.layer,
              let contentLayer = contentContainer.layer
        else {
            return false
        }

        presentationView.layoutSubtreeIfNeeded()
        let height = presentationView.bounds.height
        guard height > 0 else { return false }

        if presentationMask != nil { return true }

        let mask = CALayer()
        mask.frame = presentationView.bounds
        mask.backgroundColor = NSColor.black.cgColor
        mask.cornerRadius = cornerRadius
        mask.cornerCurve = .continuous
        mask.masksToBounds = true

        let initialTransform = initiallyHidden ? CATransform3DMakeTranslation(0, -height, 0) : CATransform3DIdentity
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mask.transform = initialTransform
        contentLayer.transform = initialTransform
        effectLayer.mask = mask
        CATransaction.commit()

        presentationMask = mask
        return true
    }

    func animateSlidePresentation(
        visible: Bool,
        duration: CFTimeInterval,
        timingFunction: CAMediaTimingFunction,
        completion: @escaping @MainActor () -> Void
    ) {
        guard let mask = presentationMask,
              let contentLayer = contentContainer.layer
        else {
            completion()
            return
        }

        slideGeneration += 1
        let generation = slideGeneration
        // 从当前屏幕位置反向衔接，避免中断动画时跳回端点。
        let currentTransform = mask.presentation()?.transform ?? mask.transform
        let targetTransform = visible
            ? CATransform3DIdentity
            : CATransform3DMakeTranslation(0, -effectView.bounds.height, 0)
        let makeAnimation = {
            let animation = CABasicAnimation(keyPath: "transform")
            animation.fromValue = currentTransform
            animation.toValue = targetTransform
            animation.duration = duration
            animation.timingFunction = timingFunction
            return animation
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [weak self] in
            MainActor.assumeIsolated {
                guard let self, generation == self.slideGeneration else { return }
                if visible { self.resetSlidePresentation() }
                completion()
            }
        }
        mask.transform = targetTransform
        contentLayer.transform = targetTransform
        mask.add(makeAnimation(), forKey: "clip.slidePresentation")
        contentLayer.add(makeAnimation(), forKey: "clip.slidePresentation")
        CATransaction.commit()
    }

    func resetSlidePresentation() {
        slideGeneration += 1
        presentationMask?.removeAllAnimations()
        contentContainer.layer?.removeAnimation(forKey: "clip.slidePresentation")

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        (presentationView ?? effectView).layer?.mask = nil
        contentContainer.layer?.transform = CATransform3DIdentity
        CATransaction.commit()

        presentationMask = nil
    }

    private func attach() {
        guard let host else { return }
        let backdropHost = presentationView ?? effectView
        host.addSubview(backdropHost)
        backdropHost.snp.remakeConstraints { make in
            make.leading.equalTo(innerPadding)
            make.trailing.equalTo(-innerPadding)
            make.top.equalToSuperview()
            make.bottom.equalTo(-innerPadding)
        }
        if let presentationView {
            // 背景和内容分别持有，切换材质不再拆动内容、焦点或动画遮罩。
            presentationView.addSubview(contentContainer)
            contentContainer.snp.remakeConstraints { $0.edges.equalToSuperview() }
            attachBackground(to: presentationView)
        } else if effectView is NSVisualEffectView {
            effectView.addSubview(contentContainer)
            contentContainer.snp.remakeConstraints { $0.edges.equalToSuperview() }
        }
    }

    private func attachBackground(to presentationView: NSView) {
        presentationView.addSubview(effectView, positioned: .below, relativeTo: contentContainer)
        effectView.snp.remakeConstraints { $0.edges.equalToSuperview() }
    }

    private static func buildEffectView(
        cornerRadius: CGFloat,
        contentContainer: NSView?
    ) -> NSView {
        if #available(macOS 26.0, *) {
            let bgType = BackgroundType(rawValue: PasteUserDefaults.backgroundType) ?? .liquid
            if bgType == .liquid {
                let glassView = NSGlassEffectView()
                glassView.wantsLayer = true
                glassView.cornerRadius = cornerRadius
                glassView.contentView = contentContainer
                return glassView
            }
        }

        let visualEffect = NSVisualEffectView()
        visualEffect.wantsLayer = true
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        if #available(macOS 26.0, *) {
            visualEffect.layer?.cornerRadius = cornerRadius
        }
        visualEffect.material = .popover
        return visualEffect
    }

    private func observeSettings() {
        UserDefaults.standard.publisher(for: \.backgroundType)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.handleSettingsChange() }
            .store(in: &cancellables)
    }

    private func handleSettingsChange() {
        let currentBgType = PasteUserDefaults.backgroundType
        guard currentBgType != lastBackgroundType else { return }
        lastBackgroundType = currentBgType
        rebuild()
    }

    private func rebuild() {
        guard let host else { return }
        let oldEffectView = effectView

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if presentationView == nil {
            if #available(macOS 26.0, *), let glassView = oldEffectView as? NSGlassEffectView {
                glassView.contentView = nil
            }
            contentContainer.removeFromSuperview()
        }

        effectView = Self.buildEffectView(
            cornerRadius: cornerRadius,
            contentContainer: presentationView == nil ? contentContainer : nil
        )
        if let presentationView {
            attachBackground(to: presentationView)
        } else {
            attach()
        }
        host.layoutSubtreeIfNeeded()
        oldEffectView.removeFromSuperview()
        CATransaction.commit()
    }
}
