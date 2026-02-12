# IsoCity iOS Host - Intent and Architecture

## Intent
- Ship a fully self-contained iOS app for the existing web-based IsoCity game.
- Keep the web game logic/rendering intact and run it inside `WKWebView`.
- Avoid external runtime dependencies: no dev URL, no prod URL, no required network for core gameplay.
- Preserve save data across app launches.

## Product Scope
- In scope:
  - Bundle-only runtime.
  - Local static hosting from app resources.
  - Persistent client-side save data.
  - Native host shell (overlay HUD + bridge wiring).
- Out of scope (current phase):
  - Multiplayer/coop support in iOS bundle mode.
  - Remote content fetching.

## High-Level Design
- The app is a native SwiftUI shell around a `WKWebView`.
- A lightweight in-process localhost server serves the exported web bundle.
- The web app loads from a stable origin: `http://127.0.0.1:54873`.
- JS/Swift communication uses a WebKit script message bridge (`bridge`).

## Why Localhost Instead of file://
- The web app expects root-relative paths like `/_next/...` and `/assets/...`.
- Serving over localhost preserves standard HTTP path behavior without rewriting asset URLs.
- A fixed port keeps origin stable for WebKit storage persistence.

## Save Persistence Model
- Saves live in web storage (`localStorage` and/or IndexedDB) inside `WKWebView`.
- Persistence requirements:
  - `WKWebsiteDataStore.default()` (persistent data store).
  - Stable origin (`127.0.0.1:54873` with constant port).
- If origin changes, stored data can appear missing due to origin scoping.

## Runtime Flow
1. Native app launches `RootGameHostView`.
2. Host verifies bundled web assets (`web.bundle/`) exist.
3. `LocalWebServer` starts on `127.0.0.1:54873`.
4. `WKWebView` loads `/index.html?host=ios&gesture=<mode>`.
5. Web app emits `host.ready` through the bridge.
6. Web app emits `host.scene` (`inGame: false`) while on the landing/co-op screens.
7. Web app emits `host.scene` (`inGame: true`) and `host.state` after the user enters a game.

## Error Handling
- Server startup failure is surfaced in native UI with retry.
- Web provisional/navigation failures are surfaced in native UI with retry.
- The app no longer relies on an infinite “waiting for bridge” state if load fails.

## Gesture Mode Split by Worktree
- `isometric-city` (`ios-web-gestures`):
  - Web layer owns gestures.
  - Host passes `gesture=web`.
- `isometric-city-ios-native-gestures` (`ios-native-gestures`):
  - Native gesture layer drives camera/tap into web bridge APIs.
  - Host passes `gesture=native`.

## Web Build and Bundling Pipeline
- iOS bundle build uses `ISOCITY_IOS_BUNDLE=1` static export configuration.
- Output is exported to `out/`.
- `npm run ios:web:bundle` copies exported files into:
  - `ios/iso-city-ios/iso-city-ios/web.bundle/`
- `web.bundle` is copied as a single resource directory into the app bundle.

## Key iOS Components
- `Host/RootGameHostView.swift`
  - App entry container, server lifecycle, load/reload, overlays.
- `Host/GameWebView.swift`
  - `WKWebView` creation, persistent data store config, bridge handler.
- `Host/LocalWebServer.swift`
  - In-process static server with path sanitization and MIME mapping.
- `Host/GameHostModel.swift`
  - Native view model for bridge state, HUD data, and load errors.
- `Host/WebViewStore.swift`
  - Shared web view reference for host interactions.

## Security/Boundary Notes
- Server serves only bundled files rooted under `web.bundle`.
- Path traversal is blocked by path sanitization and root prefix checks.
- Only basic `GET`/`HEAD` static serving is supported.

## Operational Notes
- Build/run instructions live in:
  - `ios/iso-city-ios/README.md`
- Build verification command:
  - `xcodebuild -project ios/iso-city-ios/iso-city-ios.xcodeproj -scheme iso-city-ios -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- If app shows missing bundle overlay, rerun:
  - `npm run ios:web:bundle`
