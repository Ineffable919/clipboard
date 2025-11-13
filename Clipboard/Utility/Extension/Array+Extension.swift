//
//  Array+Extension.swift
//  Clipboard
//
//  Created by crown on 2025/11/6.
//

import Foundation

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
