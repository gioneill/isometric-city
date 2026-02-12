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
    var isInGame = false
    var lastUpdate = Date()
    var loadErrorMessage: String?
    var hasReceivedHostState = false
    var debugLines: [String] = []
    var perfFPS: Int?

    var cityName = "IsoCity"
    var year = 1900
    var month = 1
    var day = 1
    var tick = 0
    var population = 0
    var money = 0
    var income = 0
    var expenses = 0
    var jobs = 0
    var residentialDemand = 0
    var commercialDemand = 0
    var industrialDemand = 0
    var speed = 1
    var selectedTool = "select"
    var activePanel = "none"
    var overlayMode = "none"
    var selectedTile: TileSelection?
    var camera = CameraState()

    struct BudgetPanelData {
        struct Stats {
            var population: Int
            var jobs: Int
            var money: Int
            var income: Int
            var expenses: Int
        }

        struct Category: Identifiable, Equatable {
            var id: String { key }
            var key: String
            var name: String
            var funding: Int
            var cost: Int
        }

        var stats: Stats
        var categories: [Category]

        init?(from map: [String: Any]) {
            guard let statsMap = map["stats"] as? [String: Any] else {
                return nil
            }
            guard let population = statsMap["population"] as? Int,
                  let jobs = statsMap["jobs"] as? Int,
                  let money = statsMap["money"] as? Int,
                  let income = statsMap["income"] as? Int,
                  let expenses = statsMap["expenses"] as? Int else {
                return nil
            }

            self.stats = Stats(population: population, jobs: jobs, money: money, income: income, expenses: expenses)

            let rawCategories = map["categories"] as? [[String: Any]] ?? []
            self.categories = rawCategories.compactMap { raw in
                guard let key = raw["key"] as? String,
                      let name = raw["name"] as? String,
                      let funding = raw["funding"] as? Int,
                      let cost = raw["cost"] as? Int else {
                    return nil
                }
                return Category(key: key, name: name, funding: funding, cost: cost)
            }
        }
    }

    struct StatisticsPanelData {
        struct Stats {
            var population: Int
            var jobs: Int
            var money: Int
            var income: Int
            var expenses: Int
            var happiness: Int
        }

        struct HistoryPoint: Identifiable, Equatable {
            var id: String { "\(year)-\(month)" }
            var year: Int
            var month: Int
            var population: Int
            var money: Int
            var happiness: Int
        }

        var stats: Stats
        var history: [HistoryPoint]

        init?(from map: [String: Any]) {
            guard let statsMap = map["stats"] as? [String: Any] else {
                return nil
            }
            guard let population = statsMap["population"] as? Int,
                  let jobs = statsMap["jobs"] as? Int,
                  let money = statsMap["money"] as? Int,
                  let income = statsMap["income"] as? Int,
                  let expenses = statsMap["expenses"] as? Int,
                  let happiness = statsMap["happiness"] as? Int else {
                return nil
            }

            self.stats = Stats(population: population, jobs: jobs, money: money, income: income, expenses: expenses, happiness: happiness)

            let rawHistory = map["history"] as? [[String: Any]] ?? []
            self.history = rawHistory.compactMap { raw in
                guard let year = raw["year"] as? Int,
                      let month = raw["month"] as? Int,
                      let population = raw["population"] as? Int,
                      let money = raw["money"] as? Int,
                      let happiness = raw["happiness"] as? Int else {
                    return nil
                }
                return HistoryPoint(year: year, month: month, population: population, money: money, happiness: happiness)
            }
        }
    }

    struct AdvisorsPanelData {
        struct Stats {
            var happiness: Int
            var health: Int
            var education: Int
            var safety: Int
            var environment: Int
        }

        struct Message: Identifiable, Equatable {
            var id: String { name + priority }
            var name: String
            var icon: String
            var messages: [String]
            var priority: String
        }

        var stats: Stats
        var advisorMessages: [Message]

        init?(from map: [String: Any]) {
            guard let statsMap = map["stats"] as? [String: Any] else {
                return nil
            }
            guard let happiness = statsMap["happiness"] as? Int,
                  let health = statsMap["health"] as? Int,
                  let education = statsMap["education"] as? Int,
                  let safety = statsMap["safety"] as? Int,
                  let environment = statsMap["environment"] as? Int else {
                return nil
            }

            self.stats = Stats(happiness: happiness, health: health, education: education, safety: safety, environment: environment)

            let rawMessages = map["advisorMessages"] as? [[String: Any]] ?? []
            self.advisorMessages = rawMessages.compactMap { raw in
                guard let name = raw["name"] as? String,
                      let icon = raw["icon"] as? String,
                      let priority = raw["priority"] as? String,
                      let messages = raw["messages"] as? [String] else {
                    return nil
                }
                return Message(name: name, icon: icon, messages: messages, priority: priority)
            }
        }
    }

    var budgetPanelData: BudgetPanelData?
    var statisticsPanelData: StatisticsPanelData?
    var advisorsPanelData: AdvisorsPanelData?

    private let selectionFeedback = UIImpactFeedbackGenerator(style: .light)
    private let toolFeedback = UIImpactFeedbackGenerator(style: .light)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private var didLogFirstHostState = false

    func handleBridgeMessage(type: String, payload: Any?) {
        DispatchQueue.main.async {
            self.lastUpdate = Date()
            switch type {
            case "host.ready":
                self.isReady = true
                self.loadErrorMessage = nil
                self.appendDebugLine("bridge host.ready")
            case "host.scene":
                self.applyHostScene(payload)
            case "host.state":
                self.hasReceivedHostState = true
                self.isInGame = true
                if !self.didLogFirstHostState {
                    self.didLogFirstHostState = true
                    self.appendDebugLine("bridge host.state")
                }
                self.applyHostState(payload)
            case "panel.data":
                self.applyPanelData(payload)
            case "camera.changed":
                self.applyCamera(payload)
            case "event.selectionChanged":
                self.selectionFeedback.impactOccurred()
                self.applySelection(payload)
            case "event.toolChanged":
                self.toolFeedback.impactOccurred()
                self.applyTool(payload)
            case "event.haptic":
                self.applyHaptic(payload)
            case "debug.console":
                self.applyConsoleDebug(payload)
            case "perf.fps":
                self.applyPerfFPS(payload)
            default:
                self.appendDebugLine("bridge \(type)")
                break
            }
        }
    }

    func handleLoadError(_ error: Error, failingURL: URL?) {
        DispatchQueue.main.async {
            self.isReady = false
            self.isInGame = false
            self.hasReceivedHostState = false
            if let failingURL {
                self.loadErrorMessage = "\(error.localizedDescription) (\(failingURL.absoluteString))"
            } else {
                self.loadErrorMessage = error.localizedDescription
            }
            self.lastUpdate = Date()
            self.appendDebugLine("loadError \(error.localizedDescription)")
        }
    }

    private func applyHostScene(_ payload: Any?) {
        guard let map = payload as? [String: Any] else { return }

        if let hudVisible = map["hudVisible"] as? Bool {
            isInGame = hudVisible
            return
        }
        if let inGame = map["inGame"] as? Bool {
            isInGame = inGame
            return
        }
        if let screen = map["screen"] as? String {
            isInGame = (screen == "game")
        }
    }

    func clearLoadError() {
        DispatchQueue.main.async {
            self.loadErrorMessage = nil
        }
    }

    func markWebContentLoaded() {
        DispatchQueue.main.async {
            self.isReady = true
            self.loadErrorMessage = nil
            self.lastUpdate = Date()
            self.appendDebugLine("webview didFinish")
        }
    }

    private func applyHostState(_ payload: Any?) {
        guard let map = payload as? [String: Any] else { return }

        cityName = stringValue(map["cityName"], fallback: cityName)
        year = intValue(map["year"], fallback: year)
        month = intValue(map["month"], fallback: month)
        day = intValue(map["day"], fallback: day)
        tick = intValue(map["tick"], fallback: tick)
        speed = intValue(map["speed"], fallback: speed)
        selectedTool = stringValue(map["selectedTool"], fallback: selectedTool)
        activePanel = stringValue(map["activePanel"], fallback: activePanel)
        overlayMode = stringValue(map["overlayMode"], fallback: overlayMode)

        if let stats = map["stats"] as? [String: Any] {
            population = intValue(stats["population"], fallback: population)
            money = intValue(stats["money"], fallback: money)
            income = intValue(stats["income"], fallback: income)
            expenses = intValue(stats["expenses"], fallback: expenses)
            jobs = intValue(stats["jobs"], fallback: jobs)
            if let demand = stats["demand"] as? [String: Any] {
                residentialDemand = intValue(demand["residential"], fallback: residentialDemand)
                commercialDemand = intValue(demand["commercial"], fallback: commercialDemand)
                industrialDemand = intValue(demand["industrial"], fallback: industrialDemand)
            }
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

    private func applyHaptic(_ payload: Any?) {
        guard let map = payload as? [String: Any] else { return }
        let style = stringValue(map["style"], fallback: "error")
        switch style {
        case "success":
            notificationFeedback.notificationOccurred(.success)
        case "warning":
            notificationFeedback.notificationOccurred(.warning)
        default:
            notificationFeedback.notificationOccurred(.error)
        }
    }

    private func applyPanelData(_ payload: Any?) {
        guard let map = payload as? [String: Any],
              let panel = map["panel"] as? String,
              let data = map["data"] as? [String: Any] else {
            return
        }

        switch panel {
        case "budget":
            budgetPanelData = BudgetPanelData(from: data)
        case "statistics":
            statisticsPanelData = StatisticsPanelData(from: data)
        case "advisors":
            advisorsPanelData = AdvisorsPanelData(from: data)
        default:
            break
        }
    }

    private func applyConsoleDebug(_ payload: Any?) {
        guard let map = payload as? [String: Any] else { return }
        let level = stringValue(map["level"], fallback: "log")
        let args = map["args"] as? [Any] ?? []
        let message = args.map { value in
            if let string = value as? String {
                return string
            }
            return String(describing: value)
        }.joined(separator: " ")
        appendDebugLine("console.\(level) \(message)")
    }

    private func applyPerfFPS(_ payload: Any?) {
        guard let map = payload as? [String: Any] else { return }
        if let fps = map["fps"] as? Int {
            perfFPS = fps
            return
        }
        if let fps = map["fps"] as? Double {
            perfFPS = Int(fps.rounded())
        }
    }

    private func appendDebugLine(_ line: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        debugLines.append("[\(timestamp)] \(line)")
        if debugLines.count > 60 {
            debugLines.removeFirst(debugLines.count - 60)
        }
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
