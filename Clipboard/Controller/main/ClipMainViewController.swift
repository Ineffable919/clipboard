//
//  ClipMainViewController.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import SnapKit

final class ClipMainViewController: NSViewController {

    private let topBarViewModel = TopBarViewModel()

    private lazy var effectView: NSView = {
        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            glassView.frame = view.frame
            glassView.cornerRadius = 34
            glassView.contentView = contentView
            return glassView
        } else {
            let effectView = NSVisualEffectView()
            effectView.wantsLayer = true
            effectView.frame = view.frame
            effectView.state = .active
            effectView.blendingMode = .behindWindow
            return effectView
        }
    }()

    private lazy var contentView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        if #available(macOS 26.0, *) {
            view.layer?.cornerRadius = 34
        }
        view.layer?.masksToBounds = true
        return view
    }()

    private lazy var topBarView: TopBarView = {
        let bar = TopBarView()
        bar.configure(viewModel: topBarViewModel)
        return bar
    }()

}

extension ClipMainViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        initView()
    }

    override func viewDidAppear() {
        view.window?.makeFirstResponder(contentView)
        view.frame = NSRect(
            x: view.frame.origin.x,
            y: -Const.defaultHeight,
            width: view.frame.width,
            height: Const.defaultHeight
        )
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.view.animator().setFrameOrigin(.zero)
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        PasteDataStore.main.clearExpiredData()
    }
}

extension ClipMainViewController {
    private func initView() {
        view.wantsLayer = true
        view.addSubview(effectView)
        if effectView is NSVisualEffectView {
            effectView.addSubview(contentView)
            contentView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        contentView.addSubview(topBarView)

        effectView.snp.makeConstraints { make in
            make.leading.equalTo(8)
            make.trailing.equalTo(-8)
            make.top.equalToSuperview()
            make.bottom.equalTo(-8)
        }

        topBarView.snp.makeConstraints { make in
            make.leading.equalTo(Const.space24)
            make.trailing.equalTo(-Const.space24)
            make.top.equalToSuperview()
            make.height.equalTo(Const.topBarHeight)
        }
    }
}
