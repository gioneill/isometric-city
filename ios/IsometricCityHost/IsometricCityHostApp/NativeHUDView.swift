import SwiftUI

private struct ToolCategory: Identifiable {
    let id: String
    let title: String
    let tools: [String]
}

private let allToolCategories: [ToolCategory] = [
    ToolCategory(id: "tools", title: "Tools", tools: ["select", "bulldoze", "road", "rail", "subway"]),
    ToolCategory(id: "zones", title: "Zones", tools: ["zone_residential", "zone_commercial", "zone_industrial", "zone_dezone", "zone_water", "zone_land"]),
    ToolCategory(id: "utilities", title: "Utilities", tools: ["power_plant", "water_tower", "subway_station", "rail_station"]),
    ToolCategory(id: "services", title: "Services", tools: ["police_station", "fire_station", "hospital", "school", "university"]),
    ToolCategory(id: "parks", title: "Parks", tools: ["park", "park_large", "tennis", "community_garden", "pond_park"]),
    ToolCategory(id: "special", title: "Special", tools: ["stadium", "museum", "airport", "space_program", "city_hall", "amusement_park"]),
]

struct NativeHUDView: View {
    @Bindable var model: GameHostModel
    @Bindable var webViewStore: WebViewStore
    @Binding var showSettings: Bool

    @State private var showToolSheet = false
    @State private var showOverlaySheet = false

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
                HStack(spacing: 8) {
                    speedButton(title: "Pause", value: 0)
                    speedButton(title: "1x", value: 1)
                    speedButton(title: "2x", value: 2)
                    speedButton(title: "3x", value: 3)
                }
            }

            if hudDensity == "full" {
                HStack(spacing: 8) {
                    panelButton(title: "Budget", panel: "budget")
                    panelButton(title: "Stats", panel: "statistics")
                    panelButton(title: "Advisors", panel: "advisors")
                    panelButton(title: "Settings", panel: "settings")
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(8)
                    .background(.thinMaterial, in: Circle())
            }
            .padding(8)
        }
    }

    private var bottomHUD: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if toolbarMode == "quick" {
                    quickToolButton("select", title: "Select")
                    quickToolButton("bulldoze", title: "Bulldoze")
                    quickToolButton("road", title: "Road")
                    quickToolButton("rail", title: "Rail")
                    quickToolButton("zone_residential", title: "R")
                    quickToolButton("zone_commercial", title: "C")
                    quickToolButton("zone_industrial", title: "I")
                } else {
                    quickToolButton("select", title: "Select")
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

                Button("Budget") { panelButtonTap("budget") }
                    .buttonStyle(CategoryButtonStyle())

                Button("Stats") { panelButtonTap("statistics") }
                    .buttonStyle(CategoryButtonStyle())

                Button("Advisors") { panelButtonTap("advisors") }
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
            setTool(tool)
        }
        .buttonStyle(QuickToolButtonStyle(isSelected: model.selectedTool == tool))
    }

    private func speedButton(title: String, value: Int) -> some View {
        Button(title) {
            webViewStore.dispatch(type: "speed.set", payload: ["speed": value])
        }
        .buttonStyle(SpeedButtonStyle(isSelected: model.speed == value))
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
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct NativeToolSheet: View {
    let selectedTool: String
    let onPickTool: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(allToolCategories) { category in
                    Section(category.title) {
                        ForEach(category.tools, id: \.self) { tool in
                            Button {
                                onPickTool(tool)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(tool.replacingOccurrences(of: "_", with: " ").capitalized)
                                    Spacer()
                                    if tool == selectedTool {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tools")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct OverlayPickerSheet: View {
    let selectedOverlay: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let overlays = ["none", "power", "water", "fire", "police", "health", "education", "subway"]

    var body: some View {
        NavigationStack {
            List(overlays, id: \.self) { overlay in
                Button {
                    onSelect(overlay)
                    dismiss()
                } label: {
                    HStack {
                        Text(overlay.capitalized)
                        Spacer()
                        if overlay == selectedOverlay {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Overlay")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct QuickToolButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.blue : Color.secondary.opacity(configuration.isPressed ? 0.45 : 0.28))
            )
    }
}

private struct SpeedButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.indigo : Color.secondary.opacity(configuration.isPressed ? 0.4 : 0.25))
            )
    }
}

private struct CategoryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.vertical, 9)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(configuration.isPressed ? 0.42 : 0.25))
            )
    }
}

private func formatCompact(_ value: Int) -> String {
    let number = Double(value)
    if number >= 1_000_000 {
        return String(format: "%.1fM", number / 1_000_000)
    }
    if number >= 1_000 {
        return String(format: "%.1fK", number / 1_000)
    }
    return "\(value)"
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

    return NativeHUDView(model: model, webViewStore: store, showSettings: .constant(false))
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

    return NativeHUDView(model: model, webViewStore: store, showSettings: .constant(false))
        .frame(width: 390, height: 844)
        .background(Color(.systemBackground))
}
