import AppKit

final class CardLayout: NSCollectionViewFlowLayout {
    override func layoutAttributesForDropTarget(
        at point: NSPoint
    ) -> NSCollectionViewLayoutAttributes? {
        guard let attributes = super.layoutAttributesForDropTarget(at: point) else { return nil }
        guard attributes.representedElementCategory == .interItemGap,
              let indexPath = attributes.indexPath
        else { return attributes }

        // FlowLayout 的命中结果不会调用下面的间隙布局方法，需要显式使用同一份尺寸。
        return layoutAttributesForInterItemGap(before: indexPath)
    }

    override func layoutAttributesForInterItemGap(before indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        guard let collectionView, indexPath.section == 0 else { return nil }
        let count = collectionView.numberOfItems(inSection: 0)
        guard count > 0, (0 ... count).contains(indexPath.item) else { return nil }

        let itemIndex = min(indexPath.item, count - 1)
        guard let frame = layoutAttributesForItem(at: IndexPath(item: itemIndex, section: 0))?.frame else {
            return nil
        }

        let centerX: CGFloat
        if indexPath.item == 0 {
            centerX = frame.minX - sectionInset.left / 2
        } else if indexPath.item == count {
            centerX = frame.maxX + sectionInset.right / 2
        } else {
            let previousPath = IndexPath(item: indexPath.item - 1, section: 0)
            guard let previousFrame = layoutAttributesForItem(at: previousPath)?.frame else { return nil }
            centerX = (previousFrame.maxX + frame.minX) / 2
        }

        // 保留原生落点语义，但隐藏系统提示器，由列表绘制整条竖线。
        let scale = collectionView.window?.backingScaleFactor ?? 2
        let cardFrame = frame.insetBy(dx: 0, dy: CollectionViewItem.cardInset(for: scale))
        let attributes = NSCollectionViewLayoutAttributes(forInterItemGapBefore: indexPath)
        attributes.frame = NSRect(x: centerX - 2, y: cardFrame.minY, width: 4, height: cardFrame.height)
        attributes.zIndex = 1
        attributes.alpha = 0
        return attributes
    }
}
