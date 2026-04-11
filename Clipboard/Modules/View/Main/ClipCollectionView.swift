//
//  ClipCollectionView.swift
//  Clipboard
//

import AppKit

final class ClipCollectionView: NSCollectionView {
    var onBecomeFirstResponder: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result { onBecomeFirstResponder?() }
        return result
    }
}
