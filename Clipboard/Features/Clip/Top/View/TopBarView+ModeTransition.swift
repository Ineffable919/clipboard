//
//  TopBarView+ModeTransition.swift
//  Clipboard
//

import AppKit

extension TopBarView {
    struct ModeChipLayer {
        let view: NSView
        let layer: CALayer
        let defaultFrame: CGRect
        let searchFrame: CGRect
        let showsInSearch: Bool
    }

    struct ModeClip {
        let view: NSView
        let clips: Bool
        let masks: Bool
    }

    func applyMode(animated: Bool = false) {
        modeAnimationGeneration += 1
        let wasSearching = modeShowsSearch
        modeShowsSearch = isSearching
        guard animated, window?.isVisible == true,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            finishModeTransition()
            return
        }
        animateModeTransition(wasHidden: !wasSearching)
    }

    /// 展开期间每帧刷新焦点环遮罩，让系统焦点环跟随搜索框的呈现宽度
    private func startModeRingTracking() {
        stopModeRingTracking()
        let link = displayLink(target: self, selector: #selector(modeRingTick))
        link.add(to: .main, forMode: .common)
        modeRingLink = link
    }

    private func stopModeRingTracking() {
        modeRingLink?.invalidate()
        modeRingLink = nil
    }

    @objc private func modeRingTick() {
        searchField.refreshFocusRingMask()
    }

    private func finishModeTransition() {
        stopModeRingTracking()
        searchField.refreshFocusRingMask()
        defaultRow.isHidden = isSearching
        searchRow.isHidden = !isSearching
        chipScrollView.alphaValue = 1
        dotChipScrollView.alphaValue = 1
        addChipBtn.alphaValue = 1
        for item in modeChipLayers {
            for layer in [item.layer, (item.view as? ChipButton)?.modeBackground,
                          (item.view as? ChipButton)?.modeLabel].compactMap({ $0 }) {
                for key in ["modeOffset", "modeWidth", "modePosition", "modeOpacity"] {
                    layer.removeAnimation(forKey: key)
                }
            }
        }
        modeChipLayers = []
        for state in modeClips {
            state.view.clipsToBounds = state.clips
            state.view.layer?.masksToBounds = state.masks
        }
        modeClips = []
        for view in modeHiddenViews { view.isHidden = false }
        modeHiddenViews = []
        for view in [searchField, searchIconBtn, searchField.modeIconView] + searchField.modeTrailingViews {
            for key in ["modeOpacity", "modeOffset", "modeWidth", "modePosition", "modeIconOpacity"] {
                view.layer?.removeAnimation(forKey: key)
            }
        }
    }

    private func animateModeTransition(wasHidden: Bool) {
        defaultRow.isHidden = false
        searchRow.isHidden = false
        layoutSubtreeIfNeeded()
        guard searchField.layer != nil else {
            finishModeTransition()
            return
        }
        let buttonFrame = searchIconBtn.convert(searchIconBtn.bounds, to: self)
        let fieldFrame = searchField.convert(searchField.bounds, to: self)
        let generation = modeAnimationGeneration

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                guard modeAnimationGeneration == generation else { return }
                finishModeTransition()
            }
        }
        if isSearching { startModeRingTracking() } else { stopModeRingTracking() }
        if modeChipLayers.isEmpty { prepareModeChips() }
        animateModeField(buttonFrame: buttonFrame, fieldFrame: fieldFrame, wasHidden: wasHidden)
        animateModeIcon(buttonFrame: buttonFrame, wasHidden: wasHidden)
        for item in modeChipLayers { animateModeChip(item, wasHidden: wasHidden) }
        CATransaction.commit()
    }

    private func animateModeField(buttonFrame: CGRect, fieldFrame: CGRect, wasHidden: Bool) {
        guard let fieldLayer = searchField.layer else { return }
        let collapsedX = fieldLayer.position.x + buttonFrame.minX - fieldFrame.minX
            + fieldLayer.anchorPoint.x * (buttonFrame.width - fieldFrame.width)
        animateModeLayer(fieldLayer, keyPath: "bounds.size.width",
                         from: wasHidden ? buttonFrame.width : fieldFrame.width,
                         to: isSearching ? fieldFrame.width : buttonFrame.width, key: "modeWidth")
        animateModeLayer(fieldLayer, keyPath: "position.x",
                         from: wasHidden ? collapsedX : fieldLayer.position.x,
                         to: isSearching ? fieldLayer.position.x : collapsedX, key: "modePosition")
        animateModeLayer(fieldLayer, keyPath: "opacity", from: wasHidden ? 0 : 1,
                         to: isSearching ? 1 : 0, key: "modeOpacity")
        for view in searchField.modeTrailingViews {
            guard let layer = view.layer else { continue }
            let offset = buttonFrame.width - fieldFrame.width
            animateModeLayer(layer, keyPath: "transform.translation.x", from: wasHidden ? offset : 0,
                             to: isSearching ? 0 : offset, key: "modeOffset")
        }
    }

    private func animateModeIcon(buttonFrame: CGRect, wasHidden: Bool) {
        let icon = searchField.modeIconView
        let searchFrame = icon.convert(icon.bounds, to: self)
        if let buttonLayer = searchIconBtn.layer {
            let offset = searchFrame.midX - buttonFrame.midX
            animateModeLayer(buttonLayer, keyPath: "transform.translation.x", from: wasHidden ? 0 : offset,
                             to: isSearching ? offset : 0, key: "modeOffset")
        }
        for (view, showsInSearch) in [(searchIconBtn as NSView, false), (icon as NSView, true)] {
            guard let layer = view.layer else { continue }
            let initial: Float = showsInSearch == !wasHidden ? 1 : 0
            let start = layer.animation(forKey: "modeIconOpacity") == nil
                ? initial : (layer.presentation()?.opacity ?? initial)
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            animation.values = [start, 0, showsInSearch == isSearching ? 1 : 0]
            animation.keyTimes = [0, 0.3, 1]
            animation.duration = 0.25
            animation.fillMode = .both
            animation.isRemovedOnCompletion = false
            layer.add(animation, forKey: "modeIconOpacity")
        }
    }

    private func prepareModeChips() {
        let dots = dotChipScrollView.modeButtons
        for (id, button) in chipScrollView.modeButtons {
            guard let dot = dots[id], !button.visibleRect.isEmpty, !dot.visibleRect.isEmpty else { continue }
            let frame = button.convert(button.bounds, to: self)
            let dotFrame = dot.convert(dot.bounds, to: self)
            let offset = dot.convert(dot.modeIconOrigin, to: self).x
                - button.convert(button.modeIconOrigin, to: self).x
            var collapsed = dotFrame.offsetBy(dx: -offset, dy: 0)
            collapsed.origin.y = frame.minY
            var expanded = frame.offsetBy(dx: offset, dy: 0)
            expanded.size.width = dotFrame.width
            addModeChip(button, defaultFrame: frame, searchFrame: expanded, showsInSearch: false)
            addModeChip(dot, defaultFrame: collapsed, searchFrame: dotFrame, showsInSearch: true)
        }
        let addFrame = addChipBtn.convert(addChipBtn.bounds, to: self)
        let dotFrame = dotChipScrollView.convert(dotChipScrollView.bounds, to: self)
        let movedAddFrame = addFrame.offsetBy(dx: dotFrame.maxX + Const.space12 - addFrame.minX, dy: 0)
        addModeChip(addChipBtn, defaultFrame: addFrame, searchFrame: movedAddFrame, showsInSearch: false)
        let buttons = Array(chipScrollView.modeButtons.values) + Array(dots.values)
        for button in buttons where !button.isHidden && !modeChipLayers.contains(where: { $0.view === button }) {
            button.isHidden = true
            modeHiddenViews.append(button)
        }
        for item in modeChipLayers { unclipModeAncestors(of: item.view) }
    }

    private func addModeChip(
        _ view: NSView, defaultFrame: CGRect, searchFrame: CGRect, showsInSearch: Bool
    ) {
        guard let layer = view.layer else { return }
        modeChipLayers.append(ModeChipLayer(
            view: view, layer: layer, defaultFrame: defaultFrame, searchFrame: searchFrame, showsInSearch: showsInSearch
        ))
    }

    private func unclipModeAncestors(of view: NSView) {
        var ancestor = view.superview
        while let parent = ancestor, parent !== self {
            if !modeClips.contains(where: { $0.view === parent }) {
                modeClips.append(ModeClip(view: parent, clips: parent.clipsToBounds,
                                          masks: parent.layer?.masksToBounds ?? false))
                parent.clipsToBounds = false
                parent.layer?.masksToBounds = false
            }
            ancestor = parent.superview
        }
    }

    private func animateModeChip(_ item: ModeChipLayer, wasHidden: Bool) {
        let source = wasHidden ? item.defaultFrame : item.searchFrame
        let target = isSearching ? item.searchFrame : item.defaultFrame
        let base = item.showsInSearch ? item.searchFrame : item.defaultFrame
        animateModeLayer(item.layer, keyPath: "transform.translation.x", from: source.minX - base.minX,
                         to: target.minX - base.minX, key: "modeOffset")
        animateModeLayer(item.layer, keyPath: "opacity",
                         from: item.showsInSearch == !wasHidden ? 1 : 0,
                         to: item.showsInSearch == isSearching ? 1 : 0, key: "modeOpacity")
        guard let button = item.view as? ChipButton, !item.showsInSearch else { return }
        let background = button.modeBackground
        let sourceWidth = max(0, background.bounds.width + source.width - base.width)
        let targetWidth = max(0, background.bounds.width + target.width - base.width)
        animateModeLayer(background, keyPath: "bounds.size.width", from: sourceWidth,
                         to: targetWidth, key: "modeWidth")
        let origin = background.frame.minX
        animateModeLayer(background, keyPath: "position.x",
                         from: origin + sourceWidth * background.anchorPoint.x,
                         to: origin + targetWidth * background.anchorPoint.x, key: "modePosition")
        if let label = button.modeLabel {
            animateModeLayer(label, keyPath: "opacity", from: wasHidden ? 1 : 0,
                             to: isSearching ? 0 : 1, key: "modeOpacity")
        }
    }

    private func animateModeLayer(
        _ layer: CALayer, keyPath: String, from start: CGFloat, to end: CGFloat, key: String
    ) {
        let previous = layer.animation(forKey: key) as? CABasicAnimation
        let current = previous.flatMap { _ in layer.presentation()?.value(forKeyPath: keyPath) }
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = current ?? previous?.fromValue ?? start
        animation.toValue = end
        animation.duration = 0.25
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: key)
    }
}
