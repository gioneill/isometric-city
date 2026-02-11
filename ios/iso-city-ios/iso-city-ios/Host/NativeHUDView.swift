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

    @AppStorage("isocity.host.toolbarMode") private var toolbarMode: String = "category"
    @AppStorage("isocity.host.hudDensity") private var hudDensity: String = "compact"

    var body: some View {
        VStack(spacing: 12) {
            topHUD
            Spacer()
            bottomHUD
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .sheet(isPresented: $showToolSheet) {
            NativeToolSheet(
                selectedTool: model.selectedTool,
                onPickTool: { tool in
                    setTool(tool)
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
                    Text(monthYearString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                statPill(title: "Pop", value: formatCompact(model.population))
                statPill(title: "Funds", value: "$\(formatCompact(model.money))")
                statPill(title: "Net", value: netValue, tint: (model.income - model.expenses) >= 0 ? .green : .red)
            }

            if hudDensity != "minimal" {
                HStack {
                    TapeDeckSpeedControl(selectedSpeed: model.speed, onSelect: setSpeed)
                    Spacer(minLength: 0)
                }
            }

            if hudDensity == "full" {
                HStack(spacing: 8) {
                    Button("Budget") {
                        requestPanelData(for: .budget)
                    }
                    .buttonStyle(CategoryButtonStyle())
                    Button("Stats") {
                        requestPanelData(for: .statistics)
                    }
                    .buttonStyle(CategoryButtonStyle())
                    Button("Advisors") {
                        requestPanelData(for: .advisors)
                    }
                    .buttonStyle(CategoryButtonStyle())
                    panelButton(title: "Settings", panel: "settings")
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var bottomHUD: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if toolbarMode == "quick" {
                    quickToolButton("bulldoze", title: "Bulldoze")
                    quickToolButton("road", title: "Road")
                    quickToolButton("rail", title: "Rail")
                    quickToolButton("zone_residential", title: "R")
                    quickToolButton("zone_commercial", title: "C")
                    quickToolButton("zone_industrial", title: "I")
                } else {
                    quickToolButton("bulldoze", title: "Bulldoze")
                    Button("Tools") { showToolSheet = true }
                        .buttonStyle(CategoryButtonStyle())
                    Button("Zones") { showToolSheet = true }
                        .buttonStyle(CategoryButtonStyle())
                    Button("Services") { showToolSheet = true }
                        .buttonStyle(CategoryButtonStyle())
                }

                Button {
                    showToolSheet = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CategoryButtonStyle())
            }

            HStack(spacing: 8) {
                Button("Overlay") {
                    showOverlaySheet = true
                }
                .buttonStyle(CategoryButtonStyle())

                Button("Budget") { requestPanelData(for: .budget) }
                    .buttonStyle(CategoryButtonStyle())

                Button("Stats") { requestPanelData(for: .statistics) }
                    .buttonStyle(CategoryButtonStyle())

                Button("Advisors") { requestPanelData(for: .advisors) }
                    .buttonStyle(CategoryButtonStyle())

                if let selectedTile = model.selectedTile {
                    Text("Tile (\(selectedTile.x), \(selectedTile.y))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func quickToolButton(_ tool: String, title: String) -> some View {
        Button(title) {
            toggleTool(tool)
        }
        .buttonStyle(QuickToolButtonStyle(isSelected: model.selectedTool == tool))
    }

    private func setSpeed(_ value: Int) {
        withAnimation(.easeInOut(duration: 0.12)) {
            model.speed = value
        }
        webViewStore.dispatch(type: "speed.set", payload: ["speed": value])
    }

    private func panelButton(title: String, panel: String) -> some View {
        Button(title) {
            panelButtonTap(panel)
        }
        .buttonStyle(CategoryButtonStyle())
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

    private func requestPanelData(for sheet: PanelSheet) {
        activePanelSheet = sheet
        webViewStore.dispatch(type: "panel.data.request", payload: ["panel": sheet.rawValue])
    }

    private func handleBudgetFunding(key: String, funding: Int) {
        webViewStore.dispatch(type: "budget.setFunding", payload: ["key": key, "funding": funding])
    }

    private var monthYearString: String {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let monthIndex = max(1, min(12, model.month)) - 1
        return "\(months[monthIndex]) \(model.year)"
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
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
}

private struct CategoryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

    private struct QuickToolButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(isSelected ? 0.25 : 0.12)))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct TapeDeckSpeedControl: View {
    let selectedSpeed: Int
    let onSelect: (Int) -> Void

    private let segmentSize = CGSize(width: 34, height: 26)

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { speed in
                let isSelected = selectedSpeed == speed

                Button {
                    onSelect(speed)
                } label: {
                    TapeDeckSegmentIcon(speed: speed)
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .frame(width: segmentSize.width, height: segmentSize.height)
                .background(
                    isSelected ? Color.white.opacity(0.22) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(isSelected ? 0.25 : 0.12), lineWidth: 1)
                )
            }
        }
        .padding(3)
        .background(
            Color.white.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct TapeDeckSegmentIcon: View {
    let speed: Int

    var body: some View {
        switch speed {
        case 0:
            TapeDeckPauseIcon()
        case 1:
            TapeDeckTriangleIcon(count: 1)
        case 2:
            TapeDeckTriangleIcon(count: 2)
        default:
            TapeDeckTriangleIcon(count: 3)
        }
    }
}

private struct TapeDeckPauseIcon: View {
    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1)
                .frame(width: 3, height: 12)
            RoundedRectangle(cornerRadius: 1)
                .frame(width: 3, height: 12)
        }
        .frame(width: 16, height: 12)
    }
}

private struct TapeDeckTriangleIcon: View {
    let count: Int

    var body: some View {
        HStack(spacing: -3) {
            ForEach(0..<count, id: \.self) { _ in
                TapeDeckTriangle()
                    .frame(width: 6, height: 10)
            }
        }
        .frame(width: CGFloat(6 + max(0, count - 1) * 3), height: 10)
    }
}

private struct TapeDeckTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct NativeToolSheet: View {
    var selectedTool: String
    var onPickTool: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Mode") {
                    Button {
                        onPickTool("select")
                        dismiss()
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
                }
                ForEach(allToolCategories) { category in
                    Section(category.title) {
                        ForEach(category.tools, id: \.self) { tool in
                            Button {
                                onPickTool(tool)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(tool)
                                        .font(.body)
                                    Spacer()
                                    if selectedTool == tool {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tools")
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
