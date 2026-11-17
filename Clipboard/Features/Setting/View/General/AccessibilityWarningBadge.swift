//
//  AccessibilityWarningBadge.swift
//  Clipboard
//
//  Created by crown on 2026/8/14
//

import SwiftUI

struct AccessibilityWarningBadge: View {
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(Color(nsColor: .systemRed))
            .frame(width: diameter, height: diameter)
            .overlay {
                Image(systemName: "exclamationmark")
                    .font(.caption2.bold())
                    .imageScale(.small)
                    .foregroundStyle(.white)
            }
    }
}
