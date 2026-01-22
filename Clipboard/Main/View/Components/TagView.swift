//
//  TagView.swift
//  Clipboard
//
//  Created by crown on 2025/12/17.
//

import SwiftUI

struct TagView: View {
    let tag: InputTag
    let onDelete: () -> Void

    private let iconSize: CGFloat = 14.0

    var body: some View {
        HStack(spacing: Const.space4) {
            tag.icon
                .frame(width: iconSize, height: iconSize)

            Text(tag.label)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .lineLimit(1)

            // Button(action: onDelete) {
            //     Image(systemName: "xmark.circle.fill")
            //         .font(.system(size: 10.0, weight: .medium))
            //         .foregroundStyle(.secondary)
            // }
            // .buttonStyle(.plain)
        }
        .padding(.horizontal, Const.space8)
        .frame(height: 20.0)
        .background(
            RoundedRectangle(cornerRadius: Const.radius * 2)
                .fill(Color.secondary.opacity(0.2))
        )
    }
}
