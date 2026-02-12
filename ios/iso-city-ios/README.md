# iOS Host App

This directory contains the native iOS host app for IsoCity. The app is a SwiftUI shell around a `WKWebView` that loads a bundled static export of the Next.js web app.

## Prereqs
- Node.js + npm (to generate the bundled web export)
- Xcode (to build/run the iOS app)

## Build The Bundled Web Export
From the repo root:

```sh
npm ci
npm run ios:web:bundle
```

This generates a static export and copies it into:
- `ios/iso-city-ios/iso-city-ios/web.bundle/` (generated; gitignored)

## Build For Simulator (No Signing)
From the repo root:

```sh
xcodebuild \
  -project ios/iso-city-ios/iso-city-ios.xcodeproj \
  -scheme iso-city-ios \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

If `generic/platform=iOS Simulator` is not accepted on your machine, list destinations and pick a simulator by name:

```sh
xcodebuild -showdestinations -scheme iso-city-ios -project ios/iso-city-ios/iso-city-ios.xcodeproj
```

Then rerun the build with `-destination 'platform=iOS Simulator,name=<Your Simulator Name>'`.

## Run In Xcode (GUI)
1. Open `ios/iso-city-ios/iso-city-ios.xcodeproj`
2. Select an iOS Simulator
3. Build/Run

## Physical Device Notes
- Building/running on a device requires selecting your own Team in Xcode Signing settings.
