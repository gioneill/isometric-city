import SwiftUI

struct StatisticsSheetView: View {
    let data: GameHostModel.StatisticsPanelData?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMetric: Metric = .population

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 16) {
                        statCard(title: "Population", value: formattedNumber(data?.stats.population))
                        statCard(title: "Jobs", value: formattedNumber(data?.stats.jobs))
                    }
                    HStack(spacing: 16) {
                        statCard(title: "Treasury", value: currencyText(data?.stats.money))
                        statCard(title: "Weekly", value: currencyText(weeklyNet()))
                    }
                    Picker("Metric", selection: $selectedMetric) {
                        ForEach(Metric.allCases) { metric in
                            Text(metric.displayName).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)

                    chartSection
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var chartSection: some View {
        Group {
            if let history = data?.history, history.count >= 2 {
                ChartCanvas(history: history, metric: selectedMetric)
                    .frame(height: 220)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                Text("Not enough data yet. Keep playing to see historical trends.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func formattedNumber(_ value: Int?) -> String {
        guard let value = value else {
            return "––"
        }
        return value.formatted(.number.grouping(.automatic))
    }

    private func currencyText(_ value: Int?) -> String {
        guard let value = value else {
            return "$––"
        }
        return "$\(value.formatted(.number.grouping(.automatic)))"
    }

    private func weeklyNet() -> Int? {
        guard let stats = data?.stats else {
            return nil
        }
        return Int(floor(Double(stats.income - stats.expenses) / 4.0))
    }
}

private enum Metric: String, CaseIterable, Identifiable {
    case population, money, happiness

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .population: return "Population"
        case .money: return "Money"
        case .happiness: return "Happiness"
        }
    }
}

private struct ChartCanvas: View {
    let history: [GameHostModel.StatisticsPanelData.HistoryPoint]
    let metric: Metric

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard let points = makePoints(in: size) else { return }

                var path = Path()
                path.addLines(points)
                context.stroke(path, with: .color(.accentColor), lineWidth: 2)

                for point in points {
                    let markerRect = CGRect(origin: CGPoint(x: point.x - 3, y: point.y - 3), size: CGSize(width: 6, height: 6))
                    context.fill(
                        Circle().path(in: markerRect),
                        with: .color(.accentColor)
                    )
                }
            }
        }
    }

    private func makePoints(in size: CGSize) -> [CGPoint]? {
        guard history.count >= 2 else { return nil }
        let values = history.map { value(for: $0) }
        guard let minValue = values.min(), let maxValue = values.max() else { return nil }
        let span = maxValue - minValue == 0 ? 1 : maxValue - minValue

        let horizontalStep = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { index, value in
            let x = horizontalStep * CGFloat(index)
            let normalized = CGFloat((value - minValue) / span)
            let y = size.height * (1 - normalized)
            return CGPoint(x: x, y: y)
        }
    }

    private func value(for point: GameHostModel.StatisticsPanelData.HistoryPoint) -> Double {
        switch metric {
        case .population:
            return Double(point.population)
        case .money:
            return Double(point.money)
        case .happiness:
            return Double(point.happiness)
        }
    }
}
