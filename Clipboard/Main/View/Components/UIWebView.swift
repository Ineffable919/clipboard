//
//  UIWebView.swift
//  Clipboard
//
//  Created by crown on 2025/10/21.
//

import SwiftUI
import WebKit

struct UIWebView: View {
    let url: URL
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .center) {
            if isLoading {
                ProgressView()
            } else {
                WebViewRepresentable(url: url)
            }
        }
        .frame(
            width: Const.maxPreviewSize - 36,
            height: Const.maxPreviewHeight,
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isLoading = false
            }
        }
    }
}

private struct WebViewRepresentable: NSViewRepresentable {
    let url: URL

    func makeNSView(context _: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context _: Context) {
        if nsView.url != url {
            let request = URLRequest(
                url: url,
                cachePolicy: .returnCacheDataElseLoad,
                timeoutInterval: 5,
            )
            nsView.load(request)
        }
    }
}

#Preview {
    let url = "https://www.apple.com.cn"
        .asCompleteURL()
    UIWebView(
        url: url!,
    )
    .frame(width: Const.maxPreviewSize, height: Const.maxPreviewHeight)
}
