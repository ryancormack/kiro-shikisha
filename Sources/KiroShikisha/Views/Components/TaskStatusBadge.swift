#if os(macOS)
import SwiftUI

/// A badge that displays the status of a task with an icon and optional label
public struct TaskStatusBadge: View {
    let status: TaskStatus
    let showLabel: Bool

    public init(status: TaskStatus, showLabel: Bool = false) {
        self.status = status
        self.showLabel = showLabel
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.iconName)
                .foregroundColor(status.displayColor)

            if showLabel {
                Text(status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TaskStatusBadge(status: .pending, showLabel: true)
        TaskStatusBadge(status: .starting, showLabel: true)
        TaskStatusBadge(status: .working, showLabel: true)
        TaskStatusBadge(status: .needsAttention, showLabel: true)
        TaskStatusBadge(status: .paused, showLabel: true)
        TaskStatusBadge(status: .completed, showLabel: true)
        TaskStatusBadge(status: .failed, showLabel: true)
        TaskStatusBadge(status: .cancelled, showLabel: true)
    }
    .padding()
}
#endif
