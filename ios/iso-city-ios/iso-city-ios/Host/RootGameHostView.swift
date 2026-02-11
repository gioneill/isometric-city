import SwiftUI

struct RootGameHostView: View {
    @State private var model = GameHostModel()
    @State private var webViewStore = WebViewStore()
    @StateObject private var server: LocalWebServer
    @State private var reloadID = UUID()
    @State private var showDebugConsole = false

    init() {
        _server = StateObject(wrappedValue: LocalWebServer(rootURL: Self.bundledWebRootURL()))
    }

    var body: some View {
        ZStack {
            if let configuration = currentConfiguration {
                GameWebView(
                    model: model,
                    webViewStore: webViewStore,
                    configuration: configuration
                )
                .id(reloadID)
                .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            if model.isInGame {
                NativeHUDView(model: model, webViewStore: webViewStore)
                    .ignoresSafeArea(edges: .all)
            }

            overlayView

            debugToggle
            if showDebugConsole {
                debugConsole
            }
        }
        .background(Color.black)
        .onAppear {
            server.startIfNeeded()
        }
    }

    private var currentConfiguration: GameLoadConfiguration? {
        guard webBundlePresent else {
            return nil
        }

        guard case .running = server.status else {
            return nil
        }

        let url = server.baseURL.appendingPathComponent("index.html")
        return GameLoadConfiguration(gameURL: url, gestureMode: "web")
    }

    private var webBundlePresent: Bool {
        Self.bundledWebRootURL() != nil
    }

    private static func bundledWebRootURL() -> URL? {
        Bundle.main.url(forResource: "web", withExtension: "bundle")
            ?? Bundle.main.resourceURL?.appendingPathComponent("web.bundle", isDirectory: true)
    }

    @ViewBuilder
    private var overlayView: some View {
        if !webBundlePresent {
            missingBundleOverlay
        } else if case .failed(let message) = server.status {
            serverFailedOverlay(message: message)
        } else if let message = model.loadErrorMessage {
            webLoadFailedOverlay(message: message)
        } else if !model.isReady {
            waitingForBridgeOverlay
                .allowsHitTesting(false)
        }
    }

    private var missingBundleOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.yellow)
            Text("Missing bundled web build")
                .font(.headline)
            Text("Run `npm run ios:web:bundle` to generate the static export and copy it into the app at `ios/iso-city-ios/iso-city-ios/web.bundle/`.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Reload") {
                reloadID = UUID()
                server.startIfNeeded()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func serverFailedOverlay(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.orange)
            Text("Local server failed")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                server.startIfNeeded()
                reloadID = UUID()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func webLoadFailedOverlay(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.orange)
            Text("Web app failed to load")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                model.clearLoadError()
                reloadID = UUID()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var waitingForBridgeOverlay: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Waiting for web app bridge…")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let configuration = currentConfiguration {
                Text(configuration.resolvedURL().absoluteString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var debugToggle: some View {
        VStack {
            HStack {
                Spacer()
                Button(showDebugConsole ? "Hide Debug" : "Show Debug") {
                    showDebugConsole.toggle()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .padding(.top, 12)
                .padding(.trailing, 12)
            }
            Spacer()
        }
    }

    private var debugConsole: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("Bridge Debug")
                    .font(.caption.weight(.semibold))
                if let configuration = currentConfiguration {
                    Text(configuration.resolvedURL().absoluteString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                ForEach(Array(model.debugLines.suffix(10).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption2.monospaced())
                        .lineLimit(2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }
}
