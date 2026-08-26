//
//  PreviewWebView.swift
//  Clipboard
//
//  链接网页预览。
//

import AppKit
import SnapKit
import WebKit

final class PreviewWebView: NSView, WKNavigationDelegate, PreviewResettable {
    private let webView: WKWebView
    private let loadingIndicator: NSProgressIndicator

    init(url: URL) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: configuration)
        loadingIndicator = NSProgressIndicator()
        super.init(frame: .zero)
        wantsLayer = true

        webView.navigationDelegate = self
        webView.alphaValue = 0

        loadingIndicator.style = .spinning
        loadingIndicator.controlSize = .regular

        addSubview(webView)
        addSubview(loadingIndicator)

        webView.snp.makeConstraints { $0.edges.equalToSuperview() }
        loadingIndicator.snp.makeConstraints { $0.center.equalToSuperview() }

        loadingIndicator.startAnimation(nil)
        webView.load(URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 10
        ))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func stopLoading() {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.loadHTMLString("", baseURL: nil)
    }

    func resetPreview() {
        stopLoading()
    }

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        finishLoading()
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
        finishLoading()
    }

    func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) {
        finishLoading()
    }

    private func finishLoading() {
        loadingIndicator.stopAnimation(nil)
        loadingIndicator.isHidden = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            webView.animator().alphaValue = 1
        }
    }
}
