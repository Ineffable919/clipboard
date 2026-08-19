//
//  WelcomeWorkflowKeyView.swift
//  Clipboard
//

import SwiftUI

struct WelcomeWorkflowKeyView: View {
    let label: String
    let width: CGFloat

    var body: some View {
        Text(verbatim: label)
            .font(.title2)
            .frame(width: width, height: 64)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(WelcomeStyle.border, lineWidth: 1)
            }
    }
}
