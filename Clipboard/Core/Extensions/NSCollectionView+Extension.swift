//
//  NSCollectionView+Extension.swift
//  Clipboard
//
//  Created by crown on 2026/4/11
//

import Cocoa

extension NSCollectionView {
    func register<T: NSCollectionViewItem & UserInterfaceItemIdentifier>(_: T.Type) {
        if let nib = T.nib {
            register(nib, forItemWithIdentifier: T.identifier)
        }
        register(T.self, forItemWithIdentifier: T.identifier)
    }
}

extension NSCollectionViewDiffableDataSource {
    /// 不动画时 AppKit 会整表 reloadData，零时长动画只做增量更新
    func applyIncrementally(
        _ snapshot: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>,
        completion: (() -> Void)? = nil
    ) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            apply(snapshot, animatingDifferences: true, completion: completion)
        }
    }
}
