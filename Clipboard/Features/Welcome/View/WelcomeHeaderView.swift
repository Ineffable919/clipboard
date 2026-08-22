//
//  WelcomeHeaderView.swift
//  Clipboard
//

import AppKit
import SwiftUI

struct WelcomeHeaderView: View {
    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .scaledToFit()
            .frame(width: 44, height: 44)
    }
}
