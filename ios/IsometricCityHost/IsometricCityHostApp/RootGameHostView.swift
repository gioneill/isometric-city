import SwiftUI

struct RootGameHostView: View {
    @State private var model = GameHostModel()
    @State private var webViewStore = WebViewStore()
    @State private var showSettings = false
    @State private var reloadID = UUID()

    @AppStorage("isocity.host.devURL") private var devURLString: String = "http://127.0.0.1:3000"
    @AppStorage("isocity.host.useDevServer") private var useDevServer: Bool = true

    var body: some View {
        ZStack {
            GameWebView(
                model: model,
                webViewStore: webViewStore,
                configuration: currentConfiguration
            )
            .id(reloadID)
            .ignoresSafeArea()

            NativeGestureLayer(model: model, webViewStore: webViewStore)
                .ignoresSafeArea()

            NativeHUDView(model: model, webViewStore: webViewStore, showSettings: $showSettings)
                .ignoresSafeArea(edges: .all)

            if !model.isReady {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Waiting for web app bridge...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(currentConfiguration.resolvedURL().absoluteString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Reload") {
                        reloadID = UUID()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .background(Color.black)
        .sheet(isPresented: $showSettings) {
            HostSettingsView(isPresented: $showSettings)
        }
        .onChange(of: devURLString) { _, _ in
            reloadID = UUID()
        }
        .onChange(of: useDevServer) { _, _ in
            reloadID = UUID()
        }
    }

    private var currentConfiguration: GameLoadConfiguration {
        GameLoadConfiguration(
            devServerURL: devURL,
            useDevServer: useDevServer,
            gestureMode: "native"
        )
    }

    private var devURL: URL {
        if let url = URL(string: devURLString) {
            return url
        }
        return URL(string: "http://127.0.0.1:3000")!
    }
}
