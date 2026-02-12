import Foundation
import SwiftUI

private struct ToolCategory: Identifiable {
    let id: String
    let title: String
    let tools: [String]
}

private let allToolCategories: [ToolCategory] = [
    ToolCategory(id: "tools", title: "Tools", tools: ["bulldoze", "road", "rail", "subway"]),
    ToolCategory(id: "zones", title: "Zones", tools: ["zone_residential", "zone_commercial", "zone_industrial", "zone_dezone", "zone_water", "zone_land"]),
    ToolCategory(id: "utilities", title: "Utilities", tools: ["power_plant", "water_tower", "subway_station", "rail_station"]),
    ToolCategory(id: "services", title: "Services", tools: ["police_station", "fire_station", "hospital", "school", "university"]),
    ToolCategory(id: "parks", title: "Parks", tools: ["park", "park_large", "tennis", "community_garden", "pond_park"]),
    ToolCategory(id: "special", title: "Special", tools: ["stadium", "museum", "airport", "space_program", "city_hall", "amusement_park"]),
]

private let allToolNames = Set(allToolCategories.flatMap(\.tools))
private let maxPinnedTools = 4

private let toolTitles: [String: String] = [
    "bulldoze": "Bulldoze",
    "road": "Road",
    "rail": "Rail",
    "subway": "Subway",
    "zone_residential": "R",
    "zone_commercial": "C",
    "zone_industrial": "I",
    "zone_dezone": "De-zone",
    "zone_water": "Water",
    "zone_land": "Land",
    "power_plant": "Power",
    "water_tower": "Water",
    "subway_station": "Subway St",
    "rail_station": "Rail St",
    "police_station": "Police",
    "fire_station": "Fire",
    "hospital": "Hospital",
    "school": "School",
    "university": "University",
    "park": "Park",
    "park_large": "Large Park",
    "tennis": "Tennis",
    "community_garden": "Garden",
    "pond_park": "Pond Park",
    "stadium": "Stadium",
    "museum": "Museum",
    "airport": "Airport",
    "space_program": "Space",
    "city_hall": "City Hall",
    "amusement_park": "Amusement"
]

private func normalizePinnedTools(_ rawTools: [String]) -> [String] {
    var seen = Set<String>()
    var normalized: [String] = []
    for tool in rawTools where allToolNames.contains(tool) {
        guard !seen.contains(tool) else { continue }
        seen.insert(tool)
        normalized.append(tool)
        if normalized.count == maxPinnedTools {
            break
        }
    }
    return normalized
}

private func decodePinnedTools(_ storageValue: String) -> [String] {
    guard let data = storageValue.data(using: .utf8),
          let decoded = try? JSONDecoder().decode([String].self, from: data) else {
        return []
    }
    return normalizePinnedTools(decoded)
}

private func encodePinnedTools(_ tools: [String]) -> String {
    let normalized = normalizePinnedTools(tools)
    guard let data = try? JSONEncoder().encode(normalized),
          let value = String(data: data, encoding: .utf8) else {
        return "[]"
    }
    return value
}

private enum PanelSheet: String, Identifiable {
    case budget
    case statistics
    case advisors

    var id: String { rawValue }
}

struct NativeHUDView: View {
    @Bindable var model: GameHostModel
    @Bindable var webViewStore: WebViewStore

    @State private var showToolSheet = false
    @State private var showOverlaySheet = false
    @State private var activePanelSheet: PanelSheet?
    @Namespace private var hudGlassNamespace

    @AppStorage("isocity.host.toolbarMode") private var toolbarMode: String = "category"
    @AppStorage("isocity.host.hudDensity") private var hudDensity: String = "compact"
    @AppStorage("isocity.host.pinnedTools") private var pinnedToolsStorage: String = "[]"

    private var pinnedTools: [String] {
        decodePinnedTools(pinnedToolsStorage)
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            ZStack(alignment: .top) {
                VStack(spacing: 12) {
                    topHUD
                    Spacer()
                    bottomHUD
                }
                .padding(.horizontal, 12)
                .padding(.top, topInset + 10)
                .padding(.bottom, 12)

                topDemandStrip
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showToolSheet) {
            NativeToolSheet(
                selectedTool: model.selectedTool,
                pinnedTools: pinnedTools,
                maxPinnedTools: maxPinnedTools,
                onPickTool: { tool in
                    toolSheetToolTapped(tool)
                },
                onTogglePin: { tool in
                    togglePinnedTool(tool)
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showOverlaySheet) {
            OverlayPickerSheet(
                selectedOverlay: model.overlayMode,
                onSelect: { overlay in
                    webViewStore.dispatch(type: "overlay.set", payload: ["mode": overlay])
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(item: $activePanelSheet) { sheet in
            switch sheet {
            case .budget:
                BudgetSheetView(data: model.budgetPanelData, onFundingChange: handleBudgetFunding)
            case .statistics:
                StatisticsSheetView(data: model.statisticsPanelData)
            case .advisors:
                AdvisorsSheetView(data: model.advisorsPanelData)
            }
        }
    }

    private var topDemandStrip: some View {
        HStack(spacing: 8) {
            DemandMiniBar(label: "R", demand: model.residentialDemand, color: .green)
                .accessibilityIdentifier("hud.demand.residential")
            DemandMiniBar(label: "C", demand: model.commercialDemand, color: .blue)
                .accessibilityIdentifier("hud.demand.commercial")
            DemandMiniBar(label: "I", demand: model.industrialDemand, color: .orange)
                .accessibilityIdentifier("hud.demand.industrial")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
        }
        .accessibilityIdentifier("hud.demand.strip")
    }

    private var topHUD: some View {
        VStack(spacing: hudDensity == "minimal" ? 6 : 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(model.isReady ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(model.cityName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dateString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.white.opacity(0.85))
                                .frame(width: 6, height: 6)
                                .scaleEffect(1 + CGFloat(dayProgress) * 0.35)
                                .animation(.easeInOut(duration: 0.15), value: dayProgress)
                            Text("Day \(currentDay) • \(timeOfDayString)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 0)
                        }
                    }
                    .layoutPriority(0)
                }

                Spacer(minLength: 8)

                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        statPill(title: "Pop", value: formatCompact(model.population))
                        statPill(title: "Funds", value: "$\(formatCompact(model.money))")
                        statPill(title: "Net", value: netValue, tint: (model.income - model.expenses) >= 0 ? .green : .red)
                    }
                }
                .layoutPriority(1)
            }

            if hudDensity != "minimal" {
                GlassEffectContainer(spacing: 8) {
                    HStack {
                        TapeDeckSpeedControl(
                            selectedSpeed: model.speed,
                            onSelect: setSpeed
                        )
                        Spacer(minLength: 0)
                    }
                }
            }

            if hudDensity == "full" {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        Button("Budget") {
                            requestPanelData(for: .budget)
                        }
                        .buttonStyle(CategoryButtonStyle(role: .panel))
                        Button("Stats") {
                            requestPanelData(for: .statistics)
                        }
                        .buttonStyle(CategoryButtonStyle(role: .panel))
                        Button("Advisors") {
                            requestPanelData(for: .advisors)
                        }
                        .buttonStyle(CategoryButtonStyle(role: .panel))
                        panelButton(title: "Settings", panel: "settings")
                    }
                }
            }
        }
        .padding(12)
        .glassEffect(.regular.tint(Color.black.opacity(0.04)), in: .rect(cornerRadius: 20))
    }

    private var bottomHUD: some View {
        VStack(spacing: 8) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    if toolbarMode == "quick" {
                        quickToolButton("bulldoze", title: "Bulldoze")
                        quickToolButton("road", title: "Road")
                        quickToolButton("rail", title: "Rail")
                        quickToolButton("zone_residential", title: "R")
                        quickToolButton("zone_commercial", title: "C")
                        quickToolButton("zone_industrial", title: "I")
                    } else {
                        ForEach(pinnedTools, id: \.self) { tool in
                            pinnedToolButton(tool)
                        }
                        Spacer(minLength: 0)
                    }

                    Button {
                        showToolSheet = true
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CategoryButtonStyle(role: .tool))
                    .frame(width: 56)
                    .accessibilityIdentifier("hud.more")
                }
            }

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button("Overlay") {
                        showOverlaySheet = true
                    }
                    .buttonStyle(CategoryButtonStyle(role: .overlay))

                    Button("Budget") { requestPanelData(for: .budget) }
                        .buttonStyle(CategoryButtonStyle(role: .panel))

                    Button("Stats") { requestPanelData(for: .statistics) }
                        .buttonStyle(CategoryButtonStyle(role: .panel))

                    Button("Advisors") { requestPanelData(for: .advisors) }
                        .buttonStyle(CategoryButtonStyle(role: .panel))

                    if let selectedTile = model.selectedTile {
                        Text("Tile (\(selectedTile.x), \(selectedTile.y))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(model.selectedTool)
                .accessibilityIdentifier("hud.selectedTool")
        }
        .animation(.smooth, value: model.selectedTool)
        .padding(10)
        .glassEffect(.regular.tint(Color.black.opacity(0.06)), in: .rect(cornerRadius: 20))
    }

    private func quickToolButton(_ tool: String, title: String) -> some View {
        Button(title) {
            toggleTool(tool)
        }
        .buttonStyle(
            QuickToolButtonStyle(
                role: roleForTool(tool),
                isSelected: model.selectedTool == tool,
                namespace: hudGlassNamespace
            )
        )
        .accessibilityIdentifier("hud.tool.\(tool)")
        .accessibilityValue(model.selectedTool == tool ? "selected" : "unselected")
    }

    private func pinnedToolButton(_ tool: String) -> some View {
        quickToolButton(tool, title: toolTitle(tool))
            .accessibilityIdentifier("hud.pinned.\(tool)")
    }

    private func setSpeed(_ value: Int) {
        withAnimation(.smooth) {
            model.speed = value
        }
        webViewStore.dispatch(type: "speed.set", payload: ["speed": value])
    }

    private func panelButton(title: String, panel: String) -> some View {
        Button(title) {
            panelButtonTap(panel)
        }
        .buttonStyle(CategoryButtonStyle(role: .panel))
    }

    private func panelButtonTap(_ panel: String) {
        webViewStore.dispatch(type: "panel.set", payload: ["panel": panel])
    }

    private func setTool(_ tool: String) {
        webViewStore.dispatch(type: "tool.set", payload: ["tool": tool])
    }

    private func toggleTool(_ tool: String) {
        if model.selectedTool == tool {
            setTool("select")
        } else {
            setTool(tool)
        }
    }

    private func toolSheetToolTapped(_ tool: String) {
        if tool == "select" {
            setTool("select")
            return
        }
        toggleTool(tool)
    }

    private func togglePinnedTool(_ tool: String) {
        var next = pinnedTools
        if let index = next.firstIndex(of: tool) {
            next.remove(at: index)
            pinnedToolsStorage = encodePinnedTools(next)
            return
        }
        guard next.count < maxPinnedTools else { return }
        next.append(tool)
        pinnedToolsStorage = encodePinnedTools(next)
    }

    private func requestPanelData(for sheet: PanelSheet) {
        activePanelSheet = sheet
        webViewStore.dispatch(type: "panel.data.request", payload: ["panel": sheet.rawValue])
    }

    private func handleBudgetFunding(key: String, funding: Int) {
        webViewStore.dispatch(type: "budget.setFunding", payload: ["key": key, "funding": funding])
    }

    private var dateString: String {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let monthIndex = max(1, min(12, model.month)) - 1
        return "\(months[monthIndex]) \(currentDay), \(model.year)"
    }

    private var currentDay: Int {
        max(1, min(30, model.day))
    }

    private var dayProgress: Double {
        let normalizedTick = Double(min(max(model.tick, 0), 30))
        return normalizedTick / 30.0
    }

    private var timeOfDayString: String {
        let totalMinutes = Int(dayProgress * 24 * 60)
        let hour = (totalMinutes / 60) % 24
        let minute = totalMinutes % 60
        return String(format: "%02d:%02d", hour, minute)
    }

    private var netValue: String {
        let net = model.income - model.expenses
        let prefix = net >= 0 ? "+" : "-"
        return "\(prefix)$\(formatCompact(abs(net)))"
    }

    private func statPill(title: String, value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private func formatCompact(_ value: Int) -> String {
        let number = Double(value)
        if number >= 1_000_000_000 {
            return String(format: "%.1fB", number / 1_000_000_000)
        }
        if number >= 1_000_000 {
            return String(format: "%.1fM", number / 1_000_000)
        }
        if number >= 1_000 {
            return String(format: "%.1fK", number / 1_000)
        }
        return "\(value)"
    }

    private func toolTitle(_ tool: String) -> String {
        toolTitles[tool] ?? tool
    }
}

private enum HUDRole {
    case info
    case tool
    case zone
    case service
    case overlay
    case panel
    case danger
}

private func roleTint(_ role: HUDRole, isSelected: Bool) -> Color {
    let base: Color
    switch role {
    case .tool:
        base = Color(red: 0.72, green: 0.78, blue: 0.86)
    case .zone:
        base = Color(red: 0.55, green: 0.72, blue: 0.96)
    case .service:
        base = Color(red: 0.95, green: 0.70, blue: 0.45)
    case .overlay:
        base = Color(red: 0.75, green: 0.62, blue: 0.95)
    case .panel:
        base = Color(red: 0.62, green: 0.90, blue: 0.72)
    case .danger:
        base = Color(red: 0.96, green: 0.45, blue: 0.45)
    case .info:
        base = Color.white
    }
    let alpha: Double = isSelected ? 0.24 : 0.18
    return base.opacity(alpha)
}

private func roleForTool(_ tool: String) -> HUDRole {
    switch tool {
    case "bulldoze":
        return .danger
    case "zone_residential", "zone_commercial", "zone_industrial", "zone_dezone", "zone_water", "zone_land":
        return .zone
    default:
        return .tool
    }
}

private extension View {
    @ViewBuilder
    func hudGlass(role: HUDRole, isInteractive: Bool, isSelected: Bool, cornerRadius: CGFloat) -> some View {
        if isInteractive {
            self.glassEffect(
                .regular.tint(roleTint(role, isSelected: isSelected)).interactive(),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        }
    }
}

private struct CategoryButtonStyle: ButtonStyle {
    let role: HUDRole

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .hudGlass(role: role, isInteractive: true, isSelected: false, cornerRadius: 14)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct QuickToolButtonStyle: ButtonStyle {
    let role: HUDRole
    var isSelected: Bool
    let namespace: Namespace.ID

    func makeBody(configuration: Configuration) -> some View {
        let base = configuration.label
            .font(.caption.weight(.semibold))
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .hudGlass(role: role, isInteractive: true, isSelected: isSelected, cornerRadius: 14)

        return Group {
            if isSelected {
                base.glassEffectID("selectedTool", in: namespace)
            } else {
                base
            }
        }
        .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct TapeDeckSpeedControl: View {
    @State private var pickerSelection: Int
    let selectedSpeed: Int
    let onSelect: (Int) -> Void

    init(selectedSpeed: Int, onSelect: @escaping (Int) -> Void) {
        self.selectedSpeed = selectedSpeed
        self.onSelect = onSelect
        self._pickerSelection = State(initialValue: selectedSpeed)
    }

    var body: some View {
        Picker("Speed", selection: $pickerSelection) {
            ForEach(0..<4, id: \.self) { speed in
                TapeDeckSegmentIcon(speed: speed)
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 14)
                    .tag(speed)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 220)
        .padding(3)
        .glassEffect(.regular.tint(Color.black.opacity(0.04)), in: .rect(cornerRadius: 16))
        .onChange(of: pickerSelection) { _, newValue in
            pickerSelectionChanged(newValue)
        }
        .onChange(of: selectedSpeed) { _, newValue in
            selectedSpeedChanged(newValue)
        }
        .animation(.smooth, value: selectedSpeed)
    }

    private func pickerSelectionChanged(_ newValue: Int) {
        guard newValue != selectedSpeed else { return }
        onSelect(newValue)
    }

    private func selectedSpeedChanged(_ newValue: Int) {
        guard pickerSelection != newValue else { return }
        pickerSelection = newValue
    }
}


private struct TapeDeckSegmentIcon: View {
    let speed: Int

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 13, weight: .semibold))
            .frame(width: 20, height: 14)
    }

    private var symbolName: String {
        switch speed {
        case 0:
            return "pause.fill"
        case 1:
            return "play.fill"
        case 2:
            return "forward.fill"
        default:
            return "forward.end.fill"
        }
    }
}

private struct DemandMiniBar: View {
    let label: String
    let demand: Int
    let color: Color

    private var percentage: CGFloat {
        CGFloat(min(100, abs(demand))) / 100
    }

    private var fillColor: Color {
        demand >= 0 ? color : .red
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 8, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                    Capsule()
                        .fill(fillColor)
                        .frame(width: max(1, proxy.size.width * percentage))
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, minHeight: 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) demand \(demand)")
    }
}

private struct NativeToolSheet: View {
    var selectedTool: String
    var pinnedTools: [String]
    var maxPinnedTools: Int
    var onPickTool: (String) -> Void
    var onTogglePin: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Mode") {
                    Button {
                        onPickTool("select")
                    } label: {
                        HStack {
                            Text("Pan / Inspect")
                                .font(.body)
                            Spacer()
                            if selectedTool == "select" {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .accessibilityIdentifier("toolSheet.tool.select")
                }
                ForEach(allToolCategories) { category in
                    Section(category.title) {
                        ForEach(category.tools, id: \.self) { tool in
                            HStack {
                                Button {
                                    onPickTool(tool)
                                } label: {
                                    HStack {
                                        Text(toolTitles[tool] ?? tool)
                                            .font(.body)
                                        Spacer()
                                        if selectedTool == tool {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.green)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("toolSheet.tool.\(tool)")

                                Button {
                                    onTogglePin(tool)
                                } label: {
                                    Image(systemName: pinnedTools.contains(tool) ? "pin.fill" : "pin")
                                        .foregroundStyle(.secondary)
                                        .font(.body)
                                }
                                .buttonStyle(.borderless)
                                .disabled(!pinnedTools.contains(tool) && pinnedTools.count >= maxPinnedTools)
                                .accessibilityIdentifier("toolSheet.pin.\(tool)")
                            }
                        }
                    }
                }
            }
            .accessibilityIdentifier("toolSheet")
            .navigationTitle("Tools")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("toolSheet.done")
                }
            }
        }
    }
}

private struct OverlayPickerSheet: View {
    var selectedOverlay: String
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private let overlays: [String] = ["none", "power", "water", "landValue", "traffic", "crime", "pollution", "happiness"]

    var body: some View {
        NavigationStack {
            List {
                ForEach(overlays, id: \.self) { overlay in
                    Button {
                        onSelect(overlay)
                        dismiss()
                    } label: {
                        HStack {
                            Text(overlay)
                            Spacer()
                            if overlay == selectedOverlay {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Overlay")
        }
    }
}

#Preview("HUD - Compact") {
    let model = GameHostModel()
    model.isReady = true
    model.cityName = "Aurora Bay"
    model.year = 2042
    model.month = 9
    model.population = 184_500
    model.money = 2_450_000
    model.income = 325_000
    model.expenses = 214_000
    model.residentialDemand = 56
    model.commercialDemand = 42
    model.industrialDemand = -14
    model.speed = 2
    model.selectedTool = "road"
    model.overlayMode = "power"
    model.selectedTile = GameHostModel.TileSelection(x: 12, y: 8)

    let store = WebViewStore()
    UserDefaults.standard.set("category", forKey: "isocity.host.toolbarMode")
    UserDefaults.standard.set("compact", forKey: "isocity.host.hudDensity")

    return NativeHUDView(model: model, webViewStore: store)
        .frame(width: 390, height: 844)
        .background(Color(.systemBackground))
}

#Preview("HUD - Full / Quick") {
    let model = GameHostModel()
    model.isReady = true
    model.cityName = "Glassport"
    model.year = 2081
    model.month = 3
    model.population = 2_420_000
    model.money = 18_750_000
    model.income = 1_420_000
    model.expenses = 1_610_000
    model.residentialDemand = 74
    model.commercialDemand = 51
    model.industrialDemand = 33
    model.speed = 3
    model.selectedTool = "zone_residential"
    model.overlayMode = "water"

    let store = WebViewStore()
    UserDefaults.standard.set("quick", forKey: "isocity.host.toolbarMode")
    UserDefaults.standard.set("full", forKey: "isocity.host.hudDensity")

    return NativeHUDView(model: model, webViewStore: store)
        .frame(width: 390, height: 844)
        .background(Color(.systemBackground))
}

#Preview("HUD - Compact") {
    let model = GameHostModel()
    model.isReady = true
    model.cityName = "Aurora Bay"
    model.year = 2042
    model.month = 9
    model.population = 184_500
    model.money = 2_450_000
    model.income = 325_000
    model.expenses = 214_000
    model.residentialDemand = 56
    model.commercialDemand = 42
    model.industrialDemand = -14
    model.speed = 2
    model.selectedTool = "road"
    model.overlayMode = "power"
    model.selectedTile = GameHostModel.TileSelection(x: 12, y: 8)

    let store = WebViewStore()
    UserDefaults.standard.set("category", forKey: "isocity.host.toolbarMode")
    UserDefaults.standard.set("compact", forKey: "isocity.host.hudDensity")

    return NativeHUDView(model: model, webViewStore: store)
        .frame(width: 390, height: 844)
        .background(Color(.systemBackground))
}

#Preview("HUD - Full / Quick") {
    let model = GameHostModel()
    model.isReady = true
    model.cityName = "Glassport"
    model.year = 2081
    model.month = 3
    model.population = 2_420_000
    model.money = 18_750_000
    model.income = 1_420_000
    model.expenses = 1_610_000
    model.residentialDemand = 74
    model.commercialDemand = 51
    model.industrialDemand = 33
    model.speed = 3
    model.selectedTool = "zone_residential"
    model.overlayMode = "water"

    let store = WebViewStore()
    UserDefaults.standard.set("quick", forKey: "isocity.host.toolbarMode")
    UserDefaults.standard.set("full", forKey: "isocity.host.hudDensity")

    return NativeHUDView(model: model, webViewStore: store)
        .frame(width: 390, height: 844)
        .background(Color(.systemBackground))
}
