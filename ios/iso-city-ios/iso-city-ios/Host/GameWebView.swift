import Foundation
import SwiftUI
import WebKit

struct GameLoadConfiguration: Equatable {
    var gameURL: URL
    var gestureMode: String = "web"

    func resolvedURL() -> URL {
        guard var components = URLComponents(url: gameURL, resolvingAgainstBaseURL: false) else {
            return gameURL
        }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "host" || $0.name == "gesture" }
        queryItems.append(URLQueryItem(name: "host", value: "ios"))
        queryItems.append(URLQueryItem(name: "gesture", value: gestureMode))
        components.queryItems = queryItems
        return components.url ?? gameURL
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
        contentController.addUserScript(WKUserScript(source: Self.consoleBridgeScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        contentController.add(context.coordinator, name: "bridge")

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true

        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.userContentController = contentController
        webConfiguration.defaultWebpagePreferences = preferences
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
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
            let url = configuration.resolvedURL()
            guard lastLoadedURL != url else { return }
            lastLoadedURL = url
            model.clearLoadError()
            webView.load(URLRequest(url: url))
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "bridge" else { return }
            guard let map = message.body as? [String: Any] else { return }
            guard let type = map["type"] as? String else { return }
            model.handleBridgeMessage(type: type, payload: map["payload"])
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webViewStore.attach(webView)
            model.markWebContentLoaded()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            model.handleLoadError(error, failingURL: webView.url ?? lastLoadedURL)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            model.handleLoadError(error, failingURL: webView.url ?? lastLoadedURL)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            model.handleLoadError(
                NSError(
                    domain: "IsoCityHost",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Web content process terminated."]
                ),
                failingURL: webView.url ?? lastLoadedURL
            )
        }
    }

    private static let consoleBridgeScript = """
    (() => {
      if (window.__isoConsoleBridgeInstalled) return;
      window.__isoConsoleBridgeInstalled = true;
      const levels = ["log", "warn", "error"];
      const stringifyArg = (value) => {
        if (typeof value === "string") return value;
        try { return JSON.stringify(value); } catch (_) { return String(value); }
      };
      const post = (level, args) => {
        try {
          window.webkit?.messageHandlers?.bridge?.postMessage({
            type: "debug.console",
            payload: { level, args: args.map(stringifyArg) }
          });
        } catch (_) {}
      };
      for (const level of levels) {
        const original = console[level];
        console[level] = (...args) => {
          post(level, args);
          if (typeof original === "function") {
            original.apply(console, args);
          }
        };
      }
    })();
    """
}
