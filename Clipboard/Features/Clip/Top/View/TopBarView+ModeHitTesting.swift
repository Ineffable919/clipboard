import AppKit

extension TopBarView {
    func modeHitTest(_ point: NSPoint, fallback: NSView?) -> NSView? {
        if modeChipLayers.isEmpty {
            if !isSearching, let fallback, fallback.isDescendant(of: searchRow) {
                return defaultRow.hitTest(convert(point, from: superview))
            }
            return isSearching && fallback === searchRow ? nil : fallback
        }
        let local = convert(point, from: superview)
        guard bounds.contains(local) else { return nil }
        for item in modeChipLayers.reversed() {
            guard let hit = modeHit(item.view, at: local) else { continue }
            return hit
        }
        if let hit = modeHit(searchIconBtn, at: local) { return hit }
        return modeHit(searchField, at: local)
    }

    private func modeHit(_ view: NSView, at point: NSPoint) -> NSView? {
        guard !view.isHidden, let layer = view.layer else { return nil }
        let visible = layer.presentation() ?? layer
        guard visible.opacity > 0.1 else { return nil }
        let parentPoint = convert(point, to: view.superview)
        guard visible.frame.contains(parentPoint) else { return nil }
        // AppKit 命中测试使用模型位置，先抵消图层动画产生的位移。
        let modelPoint = NSPoint(x: parentPoint.x + layer.frame.minX - visible.frame.minX,
                                 y: parentPoint.y + layer.frame.minY - visible.frame.minY)
        return view.hitTest(modelPoint) ?? view
    }
}
