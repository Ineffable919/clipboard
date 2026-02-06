//
//  ClipWindowView.swift
//  clipboard
//
//  Created by crown on 2025/9/11.
//

import Cocoa

final class ClipWindowView: NSPanel {
    func configureCommonSettings() {
        backgroundColor = .clear
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        titlebarSeparatorStyle = .none

        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        configureWindowSharing(
            showDuringScreenShare: PasteUserDefaults.showDuringScreenShare
        )
    }

    func configureWindowSharing(showDuringScreenShare: Bool) {
        sharingType = showDuringScreenShare ? .readOnly : .none
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}
