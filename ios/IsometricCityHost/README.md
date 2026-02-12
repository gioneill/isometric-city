# IsometricCityHost (ios-native-gestures)

Native iOS shell for IsoCity using:

- `WKWebView` for rendering
- transparent SwiftUI gesture layer (pan + pinch + tap)
- SwiftUI native HUD overlays (glass-style materials)
- JS <-> Swift bridge (`bridge.dispatch` / `window.webkit.messageHandlers.bridge.postMessage`)

This branch is **Option A** (native-owned gestures):

- SwiftUI owns pan/pinch/tap gestures.
- Gesture layer sends camera updates to JS (`window.__native.setCamera`).
- Taps route through JS hit-test/tap helpers (`window.__native.tap`).
- SwiftUI still handles native HUD, controls, sheets, and light haptics.

## Quick start

1. In the web repo root, run:

   ```bash
   npm install
   npm run dev
   ```

2. In a new terminal, generate the Xcode project (requires [XcodeGen](https://github.com/yonaskolb/XcodeGen)):

   ```bash
   cd ios/IsometricCityHost
   xcodegen generate
   open IsometricCityHost.xcodeproj
   ```

3. In Xcode:
   - set your signing team
   - run on iPhone/iPad simulator or device (iOS 26+ target)

4. In **Host Settings** inside the app:
   - set dev URL to your machine LAN IP (for physical device), e.g. `http://192.168.1.20:3000`
   - keep "Use Dev Server" enabled

The host app appends `?host=ios&gesture=native` automatically.

## Bridge contract

### Swift -> JS

Swift sends:

```js
window.bridge.dispatch({ type, payload })
```

Implemented commands:

- `tool.set`
- `speed.set`
- `panel.set`
- `overlay.set`
- `window.__native.setCamera({ offsetX, offsetY, zoom })`
- `window.__native.tap(screenX, screenY)`

### JS -> Swift

JS posts:

```js
window.webkit.messageHandlers.bridge.postMessage({ type, payload })
```

Key events:

- `host.ready`
- `host.state`
- `camera.changed`
- `event.toolChanged`
- `event.selectionChanged`
