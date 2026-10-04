//
//  WelcomeHeaderView.swift
//  Clipboard
//

import AppKit
import SwiftUI

#Preview {
    WelcomeHeaderView()
        .padding(24)
}

struct WelcomeHeaderView: View {
    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .scaledToFit()
            .frame(width: 48, height: 48)
    }
}
