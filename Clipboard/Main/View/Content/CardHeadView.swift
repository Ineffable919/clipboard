//
//  CardHeadView.swift
//  Clipboard
//
//  Created by crown on 2025/9/23.
//

import SwiftUI

struct CardHeadView: View {
    let model: PasteboardModel

    private var isSystem: Bool { model.group == -1 }

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.type.string)
                        .font(isSystem ? .headline : .title3)
                        .foregroundStyle(.white)
                    if isSystem {
                        Text(
                            model.timestamp.timeAgo(
                                relativeTo: TimeManager.shared.currentTime
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 10)

            if isSystem {
                AppIconView(appPath: model.appPath)
                    .offset(x: 15)
            }
        }
        .frame(height: Const.hdSize)
        .background(PasteDataStore.main.colorWith(model))
        .clipShape(Const.headShape)
    }
}

/// 缓存 app icon 的视图
private struct AppIconView: View {
    let appPath: String
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.clear
            }
        }
        .frame(width: Const.iconSize, height: Const.iconSize)
        .task(id: appPath) {
            icon = NSWorkspace.shared.icon(forFile: appPath)
        }
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
            tag: "string",
        ),
    )
}
