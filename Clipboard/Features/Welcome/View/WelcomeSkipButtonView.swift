//
//  WelcomeSkipButtonView.swift
//  Clipboard
//

import SwiftUI

struct WelcomeSkipButtonView: View {
    var body: some View {
        Button(.skip) {
            WelcomeWindowController.shared.skipWelcome()
        }
        .buttonStyle(.plain)
        .font(.callout.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(8)
        .contentShape(Rectangle())
    }
}
