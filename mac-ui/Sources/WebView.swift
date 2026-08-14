import AppKit
import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        context.coordinator.load(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.url = url
        if webView.url == nil {
            context.coordinator.load(in: webView)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var url: URL
        private var bootRetries = 0
        private let maxBootRetries = 4

        init(url: URL) {
            self.url = url
        }

        func load(in webView: WKWebView) {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30
            webView.load(request)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript(
                "document.body && document.body.innerText.includes('Failed to load plugins')"
            ) { result, _ in
                guard (result as? Bool) == true, self.bootRetries < self.maxBootRetries else { return }
                self.bootRetries += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.load(in: webView)
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            // Resource and script loads arrive as `.other`. Only user clicks
            // should leave the embedded page.
            guard navigationAction.navigationType == .linkActivated else { return .allow }
            guard let url = navigationAction.request.url else { return .allow }
            if let host = url.host, host == "127.0.0.1" || host == "localhost" {
                return .allow
            }
            if let scheme = url.scheme, scheme == "http" || scheme == "https" {
                NSWorkspace.shared.open(url)
                return .cancel
            }
            return .allow
        }
    }
}
