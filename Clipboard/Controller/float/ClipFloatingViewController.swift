//
//  ClipFloatingViewController.swift
//  Clipboard
//
//  Created by crown on 2025/1/14.
//

import AppKit
import SwiftUI

final class ClipFloatingViewController: NSViewController {
    private(set) var isPresented: Bool = false

    var env = AppEnvironment()

    private lazy var hostingView: NSHostingView<some View> = {
        let contentView = FloatingView()
            .environment(env)
        let v = NSHostingView(rootView: contentView)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.clear.cgColor
        return v
    }()

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

        if presented, !isPresented, hostingView.superview == nil {
            view.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(
                    equalTo: view.leadingAnchor
                ),
                hostingView.trailingAnchor.constraint(
                    equalTo: view.trailingAnchor
                ),
                hostingView.topAnchor.constraint(
                    equalTo: view.topAnchor
                ),
                hostingView.bottomAnchor.constraint(
                    equalTo: view.bottomAnchor
                ),
            ])
        }

        isPresented = presented
        completion?()
    }
}
