import SwiftUI

struct RootGameHostView: View {
    private static let landscapeHUDHideLongestSideThreshold: CGFloat = 600

    @State private var model = GameHostModel()
    @State private var webViewStore = WebViewStore()
    @StateObject private var server: LocalWebServer
    @State private var reloadID = UUID()
    @State private var showDebugConsole = false
    @State private var showPerformanceSettings = false
    @State private var fluidPanZoomEnabled = true
    @State private var debugButtonPosition: CGPoint?
    @State private var debugButtonDragStartPosition: CGPoint?
    @State private var debugButtonSize: CGSize = .zero
    @State private var selectModeBadgeSize: CGSize = .zero
    private let uiTestingEnabled = ProcessInfo.processInfo.arguments.contains("-uiTesting")

    init() {
        _server = StateObject(wrappedValue: LocalWebServer(rootURL: Self.bundledWebRootURL()))
    }

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let longestSide = max(proxy.size.width, proxy.size.height)
            let shouldHideHUD = isLandscape && longestSide <= Self.landscapeHUDHideLongestSideThreshold

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

                if model.isInGame && !shouldHideHUD {
                    NativeHUDView(model: model, webViewStore: webViewStore)
                }

                overlayView

                performanceSettingsButton
                debugToggle
                selectModeBadge
                if showDebugConsole {
                    debugConsole
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Color.black)
        .onAppear {
            server.startIfNeeded()
            syncPerfModeFromWebView()
        }
        .sheet(isPresented: $showPerformanceSettings) {
            performanceSettingsSheet
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
        return GameLoadConfiguration(gameURL: url, gestureMode: "web", uiTesting: uiTestingEnabled)
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
        GeometryReader { proxy in
            Button(debugButtonTitle) {
                showDebugConsole.toggle()
            }
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .buttonStyle(.borderedProminent)
            .background {
                GeometryReader { buttonProxy in
                    Color.clear
                        .onAppear {
                            debugButtonSize = buttonProxy.size
                        }
                        .onChange(of: buttonProxy.size) { _, newSize in
                            debugButtonSize = newSize
                        }
                }
            }
            .position(resolvedDebugButtonPosition(in: proxy.size))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let start = debugButtonDragStartPosition ?? resolvedDebugButtonPosition(in: proxy.size)
                        if debugButtonDragStartPosition == nil {
                            debugButtonDragStartPosition = start
                        }
                        let newPosition = CGPoint(
                            x: start.x + value.translation.width,
                            y: start.y + value.translation.height
                        )
                        debugButtonPosition = clampedDebugButtonPosition(newPosition, in: proxy.size)
                    }
                    .onEnded { _ in
                        debugButtonDragStartPosition = nil
                    }
            )
        }
        .ignoresSafeArea()
    }

    private var selectModeBadge: some View {
        GeometryReader { proxy in
            if model.isInGame && model.selectedTool == "select" {
                Text("Select Mode: ON")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .background {
                        GeometryReader { badgeProxy in
                            Color.clear
                                .onAppear {
                                    selectModeBadgeSize = badgeProxy.size
                                }
                                .onChange(of: badgeProxy.size) { _, newSize in
                                    selectModeBadgeSize = newSize
                                }
                        }
                    }
                    .position(
                        CGPoint(
                            x: (selectModeBadgeSize.width / 2) + 12,
                            y: resolvedDebugButtonPosition(in: proxy.size).y
                        )
                    )
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }

    private var debugButtonTitle: String {
        guard let fps = model.perfFPS else { return "--" }
        return "\(fps)"
    }

    private func resolvedDebugButtonPosition(in containerSize: CGSize) -> CGPoint {
        if let debugButtonPosition {
            return clampedDebugButtonPosition(debugButtonPosition, in: containerSize)
        }
        let defaultX = containerSize.width - (debugButtonSize.width / 2) - 12
        let defaultY = containerSize.height - (debugButtonSize.height / 2) - 12
        return clampedDebugButtonPosition(CGPoint(x: defaultX, y: defaultY), in: containerSize)
    }

    private func clampedDebugButtonPosition(_ position: CGPoint, in containerSize: CGSize) -> CGPoint {
        let halfWidth = max(debugButtonSize.width / 2, 1)
        let halfHeight = max(debugButtonSize.height / 2, 1)
        let minX = halfWidth
        let maxX = max(halfWidth, containerSize.width - halfWidth)
        let minY = halfHeight
        let maxY = max(halfHeight, containerSize.height - halfHeight)
        return CGPoint(
            x: min(max(position.x, minX), maxX),
            y: min(max(position.y, minY), maxY)
        )
    }

    private var performanceSettingsButton: some View {
        VStack {
            HStack {
                if !model.isInGame {
                    Button {
                        performanceSettingsButtonTapped()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 12)
                }
                Spacer()
            }
            Spacer()
        }
    }

    private var performanceSettingsSheet: some View {
        NavigationStack {
            Form {
                Section("Performance") {
                    Toggle("Fluid pan/zoom", isOn: $fluidPanZoomEnabled)
                        .onChange(of: fluidPanZoomEnabled) { _, newValue in
                            fluidPanZoomToggled(newValue)
                        }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showPerformanceSettings = false
                    }
                }
            }
            .onAppear {
                syncPerfModeFromWebView()
            }
        }
    }

    private func performanceSettingsButtonTapped() {
        showPerformanceSettings = true
    }

    private func fluidPanZoomToggled(_ enabled: Bool) {
        setPerfModeInWebView(enabled: enabled)
    }

    private func syncPerfModeFromWebView() {
        let script = """
        (() => {
          try {
            const raw = localStorage.getItem("isocity-perf-mode");
            if (raw === null) return true;
            return raw === "true";
          } catch (_) {
            return true;
          }
        })();
        """

        webViewStore.evaluate(script) { value in
            let enabled = (value as? Bool) ?? true
            DispatchQueue.main.async {
                self.fluidPanZoomEnabled = enabled
            }
        }
    }

    private func setPerfModeInWebView(enabled: Bool) {
        let value = enabled ? "true" : "false"
        let script = """
        (() => {
          try { localStorage.setItem("isocity-perf-mode", "\(value)"); } catch (_) {}
          try { window.dispatchEvent(new CustomEvent("isocity-perf-mode-change", { detail: \(value) })); } catch (_) {}
        })();
        """
        webViewStore.evaluate(script)
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
