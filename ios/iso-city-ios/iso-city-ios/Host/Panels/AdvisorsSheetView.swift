import SwiftUI

struct AdvisorsSheetView: View {
    let data: GameHostModel.AdvisorsPanelData?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    gradeCard
                    if let messages = data?.advisorMessages, !messages.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                advisorCard(message: message)
                            }
                        }
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "star.square")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("No urgent issues to report!")
                                .font(.headline)
                            Text("Your city is running smoothly.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding()
            }
            .navigationTitle("City Advisors")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var gradeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(overallGrade)
                    .font(.system(size: 36, weight: .black, design: .default))
                    .foregroundStyle(gradeColor)
                    .frame(width: 68, height: 68)
                    .background(gradeColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overall City Rating")
                        .font(.headline)
                    Text("Based on happiness, health, education, safety & environment")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func advisorCard(message: GameHostModel.AdvisorsPanelData.Message) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(message.icon)
                Text(message.name)
                    .font(.headline)
                Spacer()
                Text(message.priority.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor(message.priority).opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            }
            ForEach(message.messages, id: \.self) { text in
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var overallGrade: String {
        guard let stats = data?.stats else {
            return "—"
        }
        let avg = (Double(stats.happiness) + Double(stats.health) + Double(stats.education) + Double(stats.safety) + Double(stats.environment)) / 5.0
        switch avg {
        case 90...:
            return "A+"
        case 80..<90:
            return "A"
        case 70..<80:
            return "B"
        case 60..<70:
            return "C"
        case 50..<60:
            return "D"
        default:
            return "F"
        }
    }

    private var gradeColor: Color {
        guard let stats = data?.stats else {
            return .gray
        }
        let avg = (Double(stats.happiness) + Double(stats.health) + Double(stats.education) + Double(stats.safety) + Double(stats.environment)) / 5.0
        if avg >= 70 {
            return .green
        } else if avg >= 50 {
            return .yellow
        } else {
            return .red
        }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "critical":
            return .red
        case "high":
            return .orange
        case "medium":
            return .yellow
        default:
            return .gray
        }
    }
}
