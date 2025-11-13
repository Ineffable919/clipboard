//
//  EarlierWebView.swift
//  Clipboard
//
//  Created by crown on 2025/10/21.
//

import SwiftUI
import WebKit

struct EarlierWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        DispatchQueue.main.async {
            let request = URLRequest(
                url: url,
                cachePolicy: .returnCacheDataElseLoad,
                timeoutInterval: 3
            )
            nsView.load(request)
        }
    }
}

#Preview {
    let url = "https://baidu.com"
        .asCompleteURL()
    EarlierWebView(
        url: url!
    )
    .frame(width: 750, height: 480)
}
