import SwiftUI

struct BudgetSheetView: View {
    let data: GameHostModel.BudgetPanelData?
    var onFundingChange: (String, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var fundingValues: [String: Double] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    Divider()
                    categories
                }
                .padding()
            }
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                syncFundingState()
            }
            .onChange(of: data?.categories) { _ in
                syncFundingState()
            }
        }
    }

    private var header: some View {
        let stats = data?.stats

        return VStack(alignment: .leading, spacing: 8) {
            Text("Income & Expenses")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                statPill(title: "Income", value: currencyText(stats?.income))
                statPill(title: "Expenses", value: currencyText(stats?.expenses), tint: .red)
                statPill(title: "Net", value: netText(stats))
            }
        }
    }

    private var categories: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(data?.categories ?? []) { category in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(category.name)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(category.funding)%")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: binding(for: category),
                        in: 0...100,
                        step: 5
                    )
                    Text("Cost: $\(category.cost.formatted(.number.grouping(.automatic)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func binding(for category: GameHostModel.BudgetPanelData.Category) -> Binding<Double> {
        Binding(
            get: {
                fundingValues[category.key] ?? Double(category.funding)
            },
            set: { newValue in
                let rounded = max(0, min(100, (newValue / 5).rounded() * 5))
                fundingValues[category.key] = rounded
                onFundingChange(category.key, Int(rounded))
            }
        )
    }

    private func syncFundingState() {
        var snapshot: [String: Double] = [:]
        data?.categories.forEach { snapshot[$0.key] = Double($0.funding) }
        fundingValues = snapshot
    }

    private func statPill(title: String, value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func currencyText(_ value: Int?) -> String {
        guard let value = value else {
            return "$––"
        }
        return "$\(value.formatted(.number.grouping(.automatic)))"
    }

    private func netText(_ stats: GameHostModel.BudgetPanelData.Stats?) -> String {
        guard let stats = stats else {
            return "$––"
        }
        let net = stats.income - stats.expenses
        let prefix = net >= 0 ? "+" : "-"
        return "\(prefix)$\((abs(net)).formatted(.number.grouping(.automatic)))"
    }
}
