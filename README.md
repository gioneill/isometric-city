# IsoCity & IsoCoaster

This repo experiments with running the web-based IsoCity game inside a native iOS app using a SwiftUI shell and `WKWebView`. The goal is to see how blending native iOS elements with the web game affects feel and usability, without rewriting core game logic.

Key observations: Native gestures improved camera movement and made touch interactions more enjoyable than in the browser. The app felt native early on, but maintaining a SwiftUI shell in sync with a changing web app proved challenging. Performance was limited by `WKWebView`—steady 60 FPS was hard to hit—while a prototype native board was much smoother, hinting at the benefits of a native rewrite.

---

## iOS Host App

The native iOS app is a SwiftUI shell around a `WKWebView` that loads a bundled static export of the Next.js web app.

**High-Level Design**
- The app is a native SwiftUI shell around a `WKWebView`.
- A lightweight in-process localhost server serves the exported web bundle.
- The web app loads from a stable origin: `http://127.0.0.1:54873`.
- JS/Swift communication uses a WebKit script message bridge (`bridge`).

### iOS Build & Run

**Prereqs**
- Node.js + npm (to generate the bundled web export)
- Xcode (to build/run the iOS app)

**Build the bundled web export** (from repo root):
```sh
npm ci
npm run ios:web:bundle
```
This generates a static export and copies it into `ios/iso-city-ios/iso-city-ios/web.bundle/` (generated; gitignored).

**Build for simulator** (no signing):
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
If `generic/platform=iOS Simulator` is not accepted, list destinations and pick a simulator by name:
```sh
xcodebuild -showdestinations -scheme iso-city-ios -project ios/iso-city-ios/iso-city-ios.xcodeproj
```
Then rerun the build with `-destination 'platform=iOS Simulator,name=<Your Simulator Name>'`.

**Run in Xcode:** Open `ios/iso-city-ios/iso-city-ios.xcodeproj`, select an iOS Simulator, Build/Run.

**Physical device:** Building/running on a device requires selecting your own Team in Xcode Signing settings.


---

## Web Version

Open-source isometric simulation games built with **Next.js**, **TypeScript**, and **HTML5 Canvas**.

<table>
<tr>
<td width="50%" align="center"><strong>IsoCity</strong></td>
<td width="50%" align="center"><strong>IsoCoaster</strong></td>
</tr>
<tr>
<td><img src="public/readme-image.png" width="100%"></td>
<td><img src="public/readme-coaster.png" width="100%"></td>
</tr>
<tr>
<td align="center">City builder with trains, planes, cars, and pedestrians<br><a href="https://iso-city.com">iso-city.com</a></td>
<td align="center">Build theme parks with roller coasters, rides, and guests<br><a href="https://iso-coaster.com">iso-coaster.com</a></td>
</tr>
</table>

Made with [Cursor](https://cursor.com)

### Features

-   **Isometric Rendering Engine**: Custom-built rendering system using HTML5 Canvas (`CanvasIsometricGrid`) capable of handling complex depth sorting, layer management, and both image and drawn sprites.
-   **Dynamic Simulation**:
    -   **Traffic System**: Autonomous vehicles including cars, trains, and aircraft (planes/seaplanes).
    -   **Pedestrian System**: Pathfinding and crowd simulation for city inhabitants.
    -   **Economy & Resources**: Resource management, zoning (Residential, Commercial, Industrial), and city growth logic.
-   **Interactive Grid**: Tile-based placement system for buildings, roads, parks, and utilities.
-   **State Management**: Save/Load functionality for multiple cities.
-   **Responsive Design**: Mobile-friendly interface with specialized touch controls and toolbars.

### Tech Stack

-   **Framework**: [Next.js 16](https://nextjs.org/)
-   **Language**: [TypeScript](https://www.typescriptlang.org/)
-   **Graphics**: HTML5 Canvas API (No external game engine libraries; pure native implementation).
-   **Icons**: Lucide React.

### Getting Started

#### Prerequisites

-   Node.js (v18 or higher)
-   npm or yarn

#### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/amilich/isometric-city.git
    cd isometric-city
    ```

2.  **Install dependencies:**
    ```bash
    npm install
    ```

3.  **Run the development server:**
    ```bash
    npm run dev
    ```

4.  **Open the game:**
    Visit [http://localhost:3000](http://localhost:3000) in your browser.

### Contributing

Contributions are welcome! Whether it's reporting a bug, proposing a new feature, or submitting a pull request, your input is valued.

Please ensure your code follows the existing style and conventions.

---

## License

Distributed under the MIT License. See `LICENSE` for more information.
