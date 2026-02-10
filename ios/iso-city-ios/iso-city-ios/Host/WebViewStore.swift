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

    func setCamera(offsetX: Double, offsetY: Double, zoom: Double) {
        let payload: [String: Any] = [
            "offsetX": offsetX,
            "offsetY": offsetY,
            "zoom": zoom
        ]
        callNative(functionName: "setCamera", payload: payload)
    }

    func tap(screenX: Double, screenY: Double) {
        let script = """
        window.__native && window.__native.tap(\(screenX), \(screenY));
        """
        evaluate(script)
    }

    private func callNative(functionName: String, payload: [String: Any]) {
        guard
            JSONSerialization.isValidJSONObject(payload),
            let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
            let json = String(data: data, encoding: .utf8)
        else {
            return
        }

        let script = """
        window.__native && window.__native.\(functionName)(\(json));
        """
        evaluate(script)
    }
}

