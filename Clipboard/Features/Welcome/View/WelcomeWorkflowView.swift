//
//  WelcomeWorkflowView.swift
//  Clipboard
//

import SwiftUI

struct WelcomeWorkflowView: View {
    var body: some View {
        HStack(spacing: 8) {
            WelcomeSampleCardView(kind: .code, isSelected: false)
            WelcomeSampleCardView(kind: .link, isSelected: true)
            WelcomeSampleCardView(kind: .note, isSelected: false)
        }
        .frame(width: 421, height: 154)
    }
}
