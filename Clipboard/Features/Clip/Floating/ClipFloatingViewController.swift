//
//  ClipFloatingViewController.swift
//  Clipboard
//
//  Created by crown on 2025/1/14.
//

import AppKit
import SnapKit

final class ClipFloatingViewController: NSViewController {
    let env = AppEnvironment.shared

    lazy var floatingContentView = FloatingWindowContentView()
    private var monitorToken: Any?
    private var flagsMonitorToken: Any?

    // MARK: - Preview

    var previewPopover: ClipPreviewPopover?

    // MARK: - Focus

    var focusRegion: FocusRegion {
        get { env.focusRegion }
        set {
            env.focusRegion = newValue
            floatingContentView.historyView.updateSelectedItemBorder()
        }
    }

    // MARK: - Quick Paste

    var isQuickPastePressed: Bool = false {
        didSet {
            guard oldValue != isQuickPastePressed else { return }
            floatingContentView.historyView.setIsQuickPastePressed(isQuickPastePressed)
        }
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        floatingContentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(floatingContentView)
        floatingContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        floatingContentView.historyView.onTogglePreview = { [weak self] index in
            self?.togglePreview(at: index)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if monitorToken == nil {
            monitorToken = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: keyDownEvent(_:))
        }
        if flagsMonitorToken == nil {
            flagsMonitorToken = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.flagsChangedEvent(event) ?? event
            }
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        if let token = monitorToken {
            NSEvent.removeMonitor(token)
            monitorToken = nil
        }
        if let token = flagsMonitorToken {
            NSEvent.removeMonitor(token)
            flagsMonitorToken = nil
        }
        closePreview()
        isQuickPastePressed = false
        PasteDataStore.main.clearExpiredData()
    }
}
