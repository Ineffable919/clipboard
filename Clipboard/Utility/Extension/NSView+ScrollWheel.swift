//
//  NSView+ScrollWheel.swift
//  Clipboard
//

import AppKit

extension NSView {
    /// Returns all ancestor views from immediate superview up to the root.
    var ancestorChain: [NSView] {
        var chain: [NSView] = []
        var currentSuperview = superview
        while let superview = currentSuperview {
            chain.append(superview)
            currentSuperview = superview.superview
        }
        return chain
    }

    /// Recursively collects all descendant NSScrollViews.
    func descendantScrollViews() -> [NSScrollView] {
        var results: [NSScrollView] = []
        for subview in subviews {
            if let scrollView = subview as? NSScrollView {
                results.append(scrollView)
            }
            results.append(contentsOf: subview.descendantScrollViews())
        }
        return results
    }

    /// Returns the view's frame converted to window coordinates, or nil if not in a window.
    var windowFrame: CGRect? {
        guard window != nil else { return nil }
        return convert(bounds, to: nil)
    }
}
