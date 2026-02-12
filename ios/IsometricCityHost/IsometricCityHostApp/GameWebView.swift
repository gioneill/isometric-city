import Foundation
import SwiftUI
import WebKit

struct GameLoadConfiguration: Equatable {
    var devServerURL: URL
    var useDevServer: Bool = true
    var gestureMode: String = "web"

    func resolvedURL() -> URL {
        guard var components = URLComponents(url: devServerURL, resolvingAgainstBaseURL: false) else {
            return devServerURL
        }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "host" || $0.name == "gesture" }
        queryItems.append(URLQueryItem(name: "host", value: "ios"))
        queryItems.append(URLQueryItem(name: "gesture", value: gestureMode))
        components.queryItems = queryItems
        return components.url ?? devServerURL
    }
}

struct GameWebView: UIViewRepresentable {
    @Bindable var model: GameHostModel
    @Bindable var webViewStore: WebViewStore
    let configuration: GameLoadConfiguration

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model, webViewStore: webViewStore)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "bridge")

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true

        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.userContentController = contentController
        webConfiguration.defaultWebpagePreferences = preferences
        webConfiguration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .black
        webViewStore.attach(webView)
        context.coordinator.load(configuration: configuration, on: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        webViewStore.attach(uiView)
        context.coordinator.load(configuration: configuration, on: uiView)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        private var model: GameHostModel
        private var webViewStore: WebViewStore
        private var lastLoadedURL: URL?

        init(model: GameHostModel, webViewStore: WebViewStore) {
            self.model = model
            self.webViewStore = webViewStore
        }

        func load(configuration: GameLoadConfiguration, on webView: WKWebView) {
            if configuration.useDevServer {
                let url = configuration.resolvedURL()
                guard lastLoadedURL != url else { return }
                lastLoadedURL = url
                webView.load(URLRequest(url: url))
                return
            }

            if let fileURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "web") {
                guard lastLoadedURL != fileURL else { return }
                lastLoadedURL = fileURL
                webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "bridge" else { return }
            guard let map = message.body as? [String: Any] else { return }
            guard let type = map["type"] as? String else { return }
            model.handleBridgeMessage(type: type, payload: map["payload"])
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webViewStore.attach(webView)
        }
    }
}
