//
//  CGRect+Area.swift
//  Clipboard
//

import CoreGraphics

extension CGRect {
    /// The area of the rect, returning 0 for null or empty rects.
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }
}
