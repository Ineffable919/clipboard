//
//  ClipFloatingViewController.swift
//  Clipboard
//
//  Created by crown on 2025/1/14.
//

import AppKit

final class ClipFloatingViewController: NSViewController {
    private(set) var isPresented: Bool = false

    var env = AppEnvironment()

    /// AppKit 浮动内容视图，后续替换 SwiftUI NSHostingView
    var contentView: NSView?

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    func setPresented(
        _ presented: Bool,
        completion: (() -> Void)? = nil
    ) {
        guard presented != isPresented else {
            completion?()
            return
        }

        if presented, !isPresented, let cv = contentView, cv.superview == nil {
            cv.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(cv)
            NSLayoutConstraint.activate([
                cv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                cv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                cv.topAnchor.constraint(equalTo: view.topAnchor),
                cv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }

        isPresented = presented
        completion?()
    }
}
