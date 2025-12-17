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

    var body: some View {
        HStack(spacing: Const.space4) {
            tag.icon
                .font(.system(size: 10))

            Text(tag.label)
                .font(.system(size: 12))
                .lineLimit(1)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 8.0, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Const.space6)
        .padding(.vertical, Const.space4)
        .frame(height: 24.0, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Const.radius * 2)
                .fill(Color.accentColor.opacity(0.2))
        )
    }
}
