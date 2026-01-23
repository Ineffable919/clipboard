//
//  CardHeadView.swift
//  Clipboard
//
//  Created by crown on 2025/9/23.
//

import SwiftUI

struct CardHeadView: View {
    let model: PasteboardModel

    private var isDefault: Bool { model.group == -1 }

    var body: some View {
        HStack(spacing: 0) {
            CardHeadTitleView(model: model, isDefault: isDefault)
                .padding(.horizontal, 10)

            if isDefault {
                AppIconView(appPath: model.appPath)
                    .offset(x: 15)
            }
        }
        .frame(height: Const.hdSize)
        .background(PasteDataStore.main.colorWith(model))
        .clipShape(Const.headShape)
    }
}

// MARK: - Card Head Title View

private struct CardHeadTitleView: View {
    let model: PasteboardModel
    let isDefault: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.type.string)
                    .font(isDefault ? .headline : .title3)
                    .foregroundStyle(.white)

                if isDefault {
                    CardHeadTimestampView(timestamp: model.timestamp)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Card Head Timestamp View

private struct CardHeadTimestampView: View {
    let timestamp: Int64

    var body: some View {
        Text(timestamp.timeAgo(relativeTo: TimeManager.shared.currentTime))
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.85))
    }
}

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
                Image(systemName: "questionmark.app.dashed")
                    .resizable()
                    .scaledToFill()
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
            appName: "Xcode",
            searchText: "",
            length: 9,
            group: -1,
            tag: "string"
        )
    )
    .frame(width: 330.0)
    .padding()
}
