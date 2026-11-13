//
//  WelcomeSampleCardView+Preview.swift
//  Clipboard
//
//  Created by crown on 2026/9/29
//

import SwiftUI

#Preview {
    HStack(spacing: 18) {
        WelcomeSampleCardView(kind: .code, isSelected: false)
        WelcomeSampleCardView(kind: .link, isSelected: true)
        WelcomeSampleCardView(kind: .note, isSelected: false)
        WelcomeSampleCardView(kind: .color, isSelected: false)
    }
    .padding(24)
}
