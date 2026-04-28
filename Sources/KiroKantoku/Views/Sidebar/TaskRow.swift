#if os(macOS)
import SwiftUI

/// A row displaying task information in the sidebar
public struct TaskRow: View {
    let task: AgentTask

    public init(task: AgentTask) {
        self.task = task
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Status icon with color
            Image(systemName: task.status.iconName)
                .foregroundColor(task.status.displayColor)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(task.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    // Git branch badge
                    if let branch = task.gitBranch {
                        Text(branch)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.badgeCornerRadius))
                    }
                }

                // Workspace path
                Text(task.workspacePath.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Attention reason
                if task.status == .needsAttention, let reason = task.attentionReason {
                    Text(reason)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
            }

            Spacer()

            // File changes count badge
            if !task.fileChanges.isEmpty {
                Text("\(task.fileChanges.count)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: DesignConstants.badgeCornerRadius))
            }

            // Started time
            if let startedAt = task.startedAt {
                Text("Started \(startedAt, format: .dateTime.hour().minute())")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let sampleTask = AgentTask(
        name: "Implement login flow",
        status: .working,
        workspacePath: URL(fileURLWithPath: "/Users/dev/Projects/MyApp"),
        gitBranch: "feature/login",
        lastActivityAt: Date()
    )
    return TaskRow(task: sampleTask)
        .padding()
        .frame(width: 350)
}
#endif
