import SwiftUI

struct NativeGestureLayer: View {
    @Bindable var model: GameHostModel
    @Bindable var webViewStore: WebViewStore

    @State private var baseOffsetX: Double?
    @State private var baseOffsetY: Double?
    @State private var baseZoom: Double?
    @State private var panTranslation: CGSize = .zero
    @State private var pinchScale: CGFloat = 1
    @State private var isInteracting = false

    var body: some View {
        GeometryReader { _ in
            Color.clear
                .contentShape(Rectangle())
                .gesture(panGesture.simultaneously(with: pinchGesture))
                .simultaneousGesture(tapGesture)
        }
        .ignoresSafeArea()
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                beginInteractionIfNeeded()
                panTranslation = value.translation
                isInteracting = true
                pushCameraUpdate()
            }
            .onEnded { _ in
                endInteraction()
            }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                beginInteractionIfNeeded()
                pinchScale = value
                isInteracting = true
                pushCameraUpdate()
            }
            .onEnded { _ in
                endInteraction()
            }
    }

    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard !isInteracting else { return }
                webViewStore.tap(screenX: Double(value.location.x), screenY: Double(value.location.y))
            }
    }

    private func beginInteractionIfNeeded() {
        if baseOffsetX == nil || baseOffsetY == nil || baseZoom == nil {
            baseOffsetX = model.camera.offsetX
            baseOffsetY = model.camera.offsetY
            baseZoom = model.camera.zoom
        }
    }

    private func pushCameraUpdate() {
        guard let startOffsetX = baseOffsetX, let startOffsetY = baseOffsetY, let startZoom = baseZoom else {
            return
        }

        let nextZoom = max(0.25, min(3.2, startZoom * Double(pinchScale)))
        let nextOffsetX = startOffsetX + Double(panTranslation.width)
        let nextOffsetY = startOffsetY + Double(panTranslation.height)
        webViewStore.setCamera(offsetX: nextOffsetX, offsetY: nextOffsetY, zoom: nextZoom)
    }

    private func endInteraction() {
        baseOffsetX = nil
        baseOffsetY = nil
        baseZoom = nil
        panTranslation = .zero
        pinchScale = 1
        isInteracting = false
    }
}

