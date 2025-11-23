//
//  WebContentView.swift
//  Clipboard
//
//  Created by 王晶 on 2025/11/14.
//

import SwiftUI
import WebKit

@available(macOS 26.0, *)
struct WebContentView: View {
    @State private var webPage = WebPage()
    let url: URL

    var body: some View {
        ZStack(alignment: .center) {
            WebView(webPage)

            ProgressView()
                .opacity(webPage.isLoading ? 1 : 0)
        }
        .frame(
            width: Const.maxPreviewSize - 32,
            height: Const.maxPreviewHeight,
        )
        .onAppear {
            webPage.load(url)
        }
    }
}

#Preview {
    let url = URL(string: "https://www.apple.com.cn")
    if #available(macOS 26.0, *) {
        WebContentView(url: url!)
    } else {
        // Fallback on earlier versions
    }
}
