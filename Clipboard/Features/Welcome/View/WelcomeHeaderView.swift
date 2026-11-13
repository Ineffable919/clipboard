//
//  WelcomeHeaderView.swift
//  Clipboard
//
//  Created by crown on 2026/8/19
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
