//
//  NSCollectionView+Extension.swift
//  Clipboard
//
//  Created by crown on 2026/4/11.
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
