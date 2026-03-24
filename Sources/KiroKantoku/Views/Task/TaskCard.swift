#if os(macOS)
import SwiftUI

/// Compact card showing a task's current state in the dashboard
public struct TaskCard: View {
    let task: AgentTask
    let onSelect: () -> Void

    @State private var isHovered: Bool = false

    public init(task: AgentTask, onSelect: @escaping () -> Void) {
        self.task = task
        self.onSelect = onSelect
    }

    private var lastMessagePreview: String? {
        guard let lastMessage = task.messages.last else { return nil }
        let text = lastMessage.content
        if text.count > 100 { return String(text.prefix(100)) + "..." }
        return text
    }

    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Header: task name and status
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.name)
                            .font(.headline)
                            .lineLimit(1)

                        Text(task.workspacePath.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        if let branch = task.gitBranch {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.caption2)
                                Text(branch)
                                    .font(.caption2)
                            }
                            .foregroundColor(.purple)
                        }
                    }

                    Spacer()

                    // Status indicator
                    VStack(spacing: 4) {
                        Image(systemName: task.status.iconName)
                            .foregroundColor(task.status.displayColor)
                            .font(.title3)
                        Text(task.status.rawValue.capitalized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Attention banner
                if task.status == .needsAttention, let reason = task.attentionReason {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text(reason)
                            .font(.caption)
                            .lineLimit(2)
                    }
                    .foregroundColor(.orange)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium))
                }

                Divider()

                // Content: last message or file changes
                VStack(alignment: .leading, spacing: 8) {
                    if let preview = lastMessagePreview {
                        Text(preview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("No messages yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }

                    // File changes count
                    if !task.fileChanges.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                                .font(.caption2)
                            Text("\(task.fileChanges.count) file\(task.fileChanges.count == 1 ? "" : "s") changed")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                }
                .frame(minHeight: 50, alignment: .top)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.cardCornerRadius)
                    .fill(DesignConstants.cardBackground)
                    .shadow(
                        color: isHovered ? .black.opacity(0.12) : .black.opacity(0.05),
                        radius: isHovered ? 6 : DesignConstants.cardShadowRadius,
                        y: isHovered ? 3 : DesignConstants.cardShadowY
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.cardCornerRadius)
                    .stroke(
                        task.status == .needsAttention ? Color.orange.opacity(0.4) :
                        (isHovered ? Color.accentColor.opacity(0.5) :
                        DesignConstants.separatorColor.opacity(DesignConstants.cardBorderOpacity)),
                        lineWidth: task.status == .needsAttention || isHovered ? 2 : 1
                    )
            )
            .scaleEffect(isHovered ? DesignConstants.hoverScale : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    let workingTask = AgentTask(
        name: "Implement login flow",
        status: .working,
        workspacePath: URL(fileURLWithPath: "/Users/dev/Projects/MyApp"),
        gitBranch: "feature/login",
        lastActivityAt: Date(),
        messages: [
            ChatMessage(role: .user, content: "Please add a login flow"),
            ChatMessage(role: .assistant, content: "I'll implement the login flow for you. Let me start by reading the existing auth code...")
        ]
    )

    let attentionTask = AgentTask(
        name: "Fix database migration",
        status: .needsAttention,
        workspacePath: URL(fileURLWithPath: "/Users/dev/Projects/Backend"),
        attentionReason: "Agent needs approval to modify schema"
    )

    return VStack(spacing: 16) {
        TaskCard(task: workingTask, onSelect: { print("Selected working") })
        TaskCard(task: attentionTask, onSelect: { print("Selected attention") })
    }
    .padding()
    .frame(width: 350)
}
#endif
