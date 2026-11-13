//
//  CGRect+Area.swift
//  Clipboard
//
//  Created by crown on 2026/3/20
//

import CoreGraphics

extension CGRect {
    /// The area of the rect, returning 0 for null or empty rects
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }
}
