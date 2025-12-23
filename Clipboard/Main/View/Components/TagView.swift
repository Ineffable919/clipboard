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
        HStack(spacing: Const.space2) {
            tag.icon
                .frame(height: 14.0)

            Text(tag.label)
                .lineLimit(1)

        //    Button(action: onDelete) {
        //        Image(systemName: "xmark")
        //            .font(.system(size: 10.0, weight: .semibold))
        //    }
        //    .buttonStyle(.plain)
        }
        .padding(.horizontal, Const.space6)
        .padding(.vertical, Const.space2)
        .frame(height: 20.0, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Const.radius * 2)
                .fill(Color.accentColor.opacity(0.2)),
        )
    }
}
