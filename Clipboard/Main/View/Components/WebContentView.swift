//
//  WebContentView.swift
//  Clipboard
//
//  Created by crown on 2025/11/14.
//

import SwiftUI
import WebKit

@available(macOS 26.0, *)
struct WebContentView: View {
    private static let config: WebPage.Configuration = {
        var config = WebPage.Configuration()
        config.websiteDataStore = .nonPersistent()
        return config
    }()

    @State private var webPage = WebPage(configuration: config)

    let url: URL

    var body: some View {
        ZStack(alignment: .center) {
            WebView(webPage)
                .scrollBounceBehavior(.basedOnSize, axes: [.horizontal, .vertical])

            ProgressView()
                .opacity(webPage.isLoading ? 1 : 0)
        }
        .frame(
            width: Const.maxPreviewWidth - 32,
            height: Const.maxContentHeight
        )
        .onAppear {
            webPage.load(
                URLRequest(
                    url: url,
                    cachePolicy: .reloadIgnoringLocalCacheData,
                    timeoutInterval: 5.0
                )
            )
        }
        .onDisappear {
            webPage.stopLoading()
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
