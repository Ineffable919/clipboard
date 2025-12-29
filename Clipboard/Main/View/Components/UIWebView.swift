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
        ZStack {
            WebViewRepresentable(url: url, isLoading: $isLoading)
                .opacity(isLoading ? 0 : 1)

            if isLoading {
                ProgressView()
            }
        }
        .frame(
            width: Const.maxPreviewWidth - 36,
            height: Const.maxContentHeight,
        )
    }
}

private struct WebViewRepresentable: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        if let scrollView = webView.enclosingScrollView {
            scrollView.hasHorizontalScroller = true
            scrollView.hasVerticalScroller = true
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context _: Context) {
        if nsView.url != url {
            let request = URLRequest(
                url: url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 5,
            )
            nsView.load(request)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func webView(_: WKWebView, didFinish _: WKNavigation!) {
            isLoading = false
        }

        func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            isLoading = false
        }

        func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) {
            isLoading = false
        }
    }
}

#Preview {
    let url = "https://www.apple.com.cn"
        .asCompleteURL()
    UIWebView(url: url!)
        .frame(width: Const.maxPreviewWidth, height: Const.maxPreviewHeight)
}
