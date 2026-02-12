import Foundation
import Observation
import UIKit

@Observable
final class GameHostModel {
    struct CameraState {
        var offsetX: Double = 0
        var offsetY: Double = 0
        var zoom: Double = 1
        var canvasWidth: Double = 0
        var canvasHeight: Double = 0
    }

    struct TileSelection {
        var x: Int
        var y: Int
    }

    var isReady = false
    var lastUpdate = Date()

    var cityName = "IsoCity"
    var year = 1900
    var month = 1
    var population = 0
    var money = 0
    var income = 0
    var expenses = 0
    var speed = 1
    var selectedTool = "select"
    var activePanel = "none"
    var overlayMode = "none"
    var selectedTile: TileSelection?
    var camera = CameraState()

    private let selectionFeedback = UIImpactFeedbackGenerator(style: .light)
    private let toolFeedback = UIImpactFeedbackGenerator(style: .light)

    func handleBridgeMessage(type: String, payload: Any?) {
        DispatchQueue.main.async {
            self.lastUpdate = Date()
            switch type {
            case "host.ready":
                self.isReady = true
            case "host.state":
                self.applyHostState(payload)
            case "camera.changed":
                self.applyCamera(payload)
            case "event.selectionChanged":
                self.selectionFeedback.impactOccurred()
                self.applySelection(payload)
            case "event.toolChanged":
                self.toolFeedback.impactOccurred()
                self.applyTool(payload)
            default:
                break
            }
        }
    }

    private func applyHostState(_ payload: Any?) {
        guard let map = payload as? [String: Any] else { return }

        cityName = stringValue(map["cityName"], fallback: cityName)
        year = intValue(map["year"], fallback: year)
        month = intValue(map["month"], fallback: month)
        speed = intValue(map["speed"], fallback: speed)
        selectedTool = stringValue(map["selectedTool"], fallback: selectedTool)
        activePanel = stringValue(map["activePanel"], fallback: activePanel)
        overlayMode = stringValue(map["overlayMode"], fallback: overlayMode)

        if let stats = map["stats"] as? [String: Any] {
            population = intValue(stats["population"], fallback: population)
            money = intValue(stats["money"], fallback: money)
            income = intValue(stats["income"], fallback: income)
            expenses = intValue(stats["expenses"], fallback: expenses)
        }

        if let tile = map["selectedTile"] as? [String: Any] {
            let x = intValue(tile["x"], fallback: 0)
            let y = intValue(tile["y"], fallback: 0)
            selectedTile = TileSelection(x: x, y: y)
        } else {
            selectedTile = nil
        }
    }

    private func applyCamera(_ payload: Any?) {
        guard let map = payload as? [String: Any] else { return }
        camera.offsetX = doubleValue(map["offsetX"], fallback: camera.offsetX)
        camera.offsetY = doubleValue(map["offsetY"], fallback: camera.offsetY)
        camera.zoom = doubleValue(map["zoom"], fallback: camera.zoom)
        camera.canvasWidth = doubleValue(map["canvasWidth"], fallback: camera.canvasWidth)
        camera.canvasHeight = doubleValue(map["canvasHeight"], fallback: camera.canvasHeight)
    }

    private func applySelection(_ payload: Any?) {
        if let map = payload as? [String: Any] {
            let x = intValue(map["x"], fallback: 0)
            let y = intValue(map["y"], fallback: 0)
            selectedTile = TileSelection(x: x, y: y)
        } else {
            selectedTile = nil
        }
    }

    private func applyTool(_ payload: Any?) {
        guard let map = payload as? [String: Any] else { return }
        selectedTool = stringValue(map["tool"], fallback: selectedTool)
    }
}

private func intValue(_ raw: Any?, fallback: Int) -> Int {
    if let int = raw as? Int { return int }
    if let double = raw as? Double { return Int(double) }
    if let number = raw as? NSNumber { return number.intValue }
    return fallback
}

private func doubleValue(_ raw: Any?, fallback: Double) -> Double {
    if let double = raw as? Double { return double }
    if let int = raw as? Int { return Double(int) }
    if let number = raw as? NSNumber { return number.doubleValue }
    return fallback
}

private func stringValue(_ raw: Any?, fallback: String) -> String {
    if let string = raw as? String { return string }
    return fallback
}
