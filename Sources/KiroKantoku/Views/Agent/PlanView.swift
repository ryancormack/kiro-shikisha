#if os(macOS)
import SwiftUI
import ACPModel

/// Collapsible view showing the agent's execution plan with step progress
struct PlanView: View {
    let plan: PlanUpdate
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 10)
                    Image(systemName: "list.bullet.clipboard")
                        .foregroundColor(.blue)
                        .frame(width: 14)
                    Text("Plan")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("\(completedCount)/\(plan.entries.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(plan.entries.enumerated()), id: \.offset) { _, entry in
                        HStack(spacing: 6) {
                            Image(systemName: statusIcon(for: entry.status))
                                .font(.caption)
                                .foregroundColor(statusColor(for: entry.status))
                                .frame(width: 14)
                            Text(entry.content)
                                .font(.caption)
                                .foregroundColor(entry.status == .completed ? .secondary : .primary)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
        .background(DesignConstants.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium))
    }

    private var completedCount: Int {
        plan.entries.filter { $0.status == .completed }.count
    }

    private func statusIcon(for status: PlanEntryStatus) -> String {
        switch status {
        case .completed: return "checkmark.circle.fill"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .pending: return "circle"
        }
    }

    private func statusColor(for status: PlanEntryStatus) -> Color {
        switch status {
        case .completed: return .green
        case .inProgress: return .blue
        case .pending: return .secondary
        }
    }
}
#endif
