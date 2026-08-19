//
//  WelcomeWorkflowView.swift
//  Clipboard
//

import SwiftUI

struct WelcomeWorkflowView: View {
    var body: some View {
        HStack(spacing: 0) {
            WelcomeWorkflowKeyView(label: "⌘ C", width: 68)

            Rectangle()
                .fill(WelcomeStyle.border)
                .frame(width: 22, height: 1)

            ZStack {
                Circle()
                    .stroke(
                        WelcomeStyle.border,
                        style: StrokeStyle(
                            lineWidth: 1,
                            dash: [5, 4]
                        )
                    )

                Text(verbatim: "Clip")
                    .font(.title3.weight(.medium))
                    .frame(width: 62, height: 62)
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(WelcomeStyle.border, lineWidth: 1)
                    }

                Circle()
                    .fill(WelcomeStyle.accent)
                    .frame(width: 7, height: 7)
                    .offset(x: 37, y: -36)
            }
            .frame(width: 88, height: 88)

            Rectangle()
                .fill(WelcomeStyle.border)
                .frame(width: 22, height: 1)

            WelcomeWorkflowKeyView(label: "⌘ ⇧ V", width: 90)
        }
        .frame(maxWidth: .infinity)
    }
}
