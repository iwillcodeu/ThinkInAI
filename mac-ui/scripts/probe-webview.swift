import AppKit
import Foundation
import WebKit

final class Probe: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    let webView: WKWebView
    var finished = false

    override init() {
        let config = WKWebViewConfiguration()
        let console = """
        (function () {
          function send(kind, args) {
            try {
              window.webkit.messageHandlers.probe.postMessage({
                kind: kind,
                text: Array.from(args).map(function (a) {
                  if (a && a.stack) return String(a) + "\\n" + a.stack;
                  return typeof a === "string" ? a : JSON.stringify(a);
                }).join(" ");
              });
            } catch (e) {}
          }
          ["log", "info", "warn", "error"].forEach(function (kind) {
            var orig = console[kind];
            console[kind] = function () {
              send(kind, arguments);
              return orig.apply(console, arguments);
            };
          });
          window.addEventListener("error", function (ev) {
            send("error", [ev.message + " at " + ev.filename + ":" + ev.lineno]);
          });
          window.addEventListener("unhandledrejection", function (ev) {
            send("error", ["unhandledrejection " + String(ev.reason)]);
          });
        })();
        """
        let script = WKUserScript(source: console, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1200, height: 800), configuration: config)
        super.init()
        config.userContentController.add(self, name: "probe")
        webView.navigationDelegate = self
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        print("CONSOLE \(message.body)")
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        let url = navigationAction.request.url?.absoluteString ?? "<nil>"
        print("NAV type=\(navigationAction.navigationType.rawValue) url=\(url)")
        return .allow
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("DID_FINISH \(webView.url?.absoluteString ?? "")")
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            webView.evaluateJavaScript(
                "document.body ? document.body.innerText.slice(0, 4000) : ''"
            ) { result, error in
                if let error { print("EVAL_ERROR \(error)") }
                print("BODY_TEXT_BEGIN")
                print(result ?? "")
                print("BODY_TEXT_END")
                self.finished = true
                NSApp.terminate(nil)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("DID_FAIL \(error)")
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        print("DID_FAIL_PROVISIONAL \(error)")
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let probe = Probe()
app.delegate = nil
probe.webView.load(URLRequest(url: URL(string: "http://127.0.0.1:3080/")!))
app.run()
