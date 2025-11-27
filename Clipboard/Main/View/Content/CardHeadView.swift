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
            let isSystem = model.group == -1
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.type.string)
                        .font(isSystem ? .headline : .title3)
                        .foregroundStyle(.white)
                    if isSystem {
                        Text(
                            model.timestamp.timeAgo(
                                relativeTo: TimeManager.shared.currentTime,
                            ),
                        )
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 10)

            if isSystem {
                Image(nsImage: NSWorkspace.shared.icon(forFile: model.appPath))
                    .resizable()
                    .scaledToFill()
                    .frame(width: Const.iconSize, height: Const.iconSize)
                    .offset(x: 15)
            }
        }
        .frame(height: Const.hdSize)
        .background(Color(nsColor: PasteDataStore.main.colorWith(model)))
        .clipShape(Const.headShape)
    }
}

#Preview {
    let data = "Clipboard".data(using: .utf8)
    CardHeadView(
        model: PasteboardModel(
            pasteboardType: PasteboardType.string,
            data: data!,
            showData: Data(),
            timestamp: 1_728_878_384_000,
            appPath: "/Applications/Xcode.app",
            appName: "微信", 
            searchText: "",
            length: 9,
            group: -1,
        )
    )
}
