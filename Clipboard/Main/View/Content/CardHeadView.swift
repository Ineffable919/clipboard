//
//  CardHeadView.swift
//  Clipboard
//
//  Created by crown on 2025/9/23.
//

import SwiftUI

struct CardHeadView: View {
    var model: PasteboardModel

    var body: some View {
        ZStack(alignment: .trailing) {
            Const.headShape
                .fill(Color(PasteDataStore.main.colorWith(model)))
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.type.string)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(
                        model.timestamp.timeAgo(
                            relativeTo: TimeManager.shared.currentTime,
                        ),
                    )
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }
            .padding(.horizontal, 10)

            if model.group == -1 {
                Image(nsImage: NSWorkspace.shared.icon(forFile: model.appPath))
                    .resizable()
                    .scaledToFill()
                    .frame(width: Const.iconSize, height: Const.iconSize)
                    .offset(x: 15)
            }
        }
        .frame(height: Const.hdSize)
        .clipShape(Const.headShape)
    }
}
