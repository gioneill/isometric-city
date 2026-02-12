import Foundation
import Observation
import WebKit

@Observable
final class WebViewStore {
    var webView: WKWebView?

    func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    func dispatch(type: String, payload: [String: Any] = [:]) {
        guard let webView else { return }

        let envelope: [String: Any] = [
            "type": type,
            "payload": payload
        ]

        guard
            JSONSerialization.isValidJSONObject(envelope),
            let data = try? JSONSerialization.data(withJSONObject: envelope, options: []),
            let json = String(data: data, encoding: .utf8)
        else {
            return
        }

        let script = """
        window.bridge && window.bridge.dispatch(\(json));
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func evaluate(_ script: String) {
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func evaluate(_ script: String, completion: @escaping (Any?) -> Void) {
        webView?.evaluateJavaScript(script) { result, _ in
            completion(result)
        }
    }
}
