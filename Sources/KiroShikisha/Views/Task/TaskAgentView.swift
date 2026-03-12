#if os(macOS)
import SwiftUI

/// View showing an agent working on a task, with task context header
public struct TaskAgentView: View {
    let task: AgentTask
    @Environment(AgentManager.self) var agentManager
    @Environment(TaskManager.self) var taskManager

    public init(task: AgentTask) {
        self.task = task
    }

    /// The agent running this task, if any
    private var agent: Agent? {
        guard let agentId = task.agentId else { return nil }
        return agentManager.getAgent(id: agentId)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Task info header
            taskHeader

            Divider()

            // Main content
            if let agent = agent {
                // Agent is running - show the standard agent view
                HSplitView {
                    ChatPanel(agent: agent)
                        .frame(minWidth: 300)

                    CodePanel(agent: agent, workspacePath: task.workspacePath)
                        .frame(minWidth: 200, idealWidth: 320, maxWidth: 500)
                }
            } else if task.status == .pending {
                // Task created but not started
                TaskPendingView(task: task)
            } else if task.status == .starting {
                // Task is starting up
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Starting task...")
                        .font(.headline)
                    Text("Connecting to agent for \(task.workspacePath.lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if task.status.isTerminal {
                // Task is completed/failed/cancelled - show summary
                TaskCompletedView(task: task)
            } else {
                // Fallback
                VStack(spacing: 16) {
                    Image(systemName: task.status.iconName)
                        .font(.system(size: 48))
                        .foregroundColor(task.status.displayColor)
                    Text(task.name)
                        .font(.title2)
                    Text("Status: \(task.status.rawValue.capitalized)")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(task.name)
    }

    private var taskHeader: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: task.status.iconName)
                .foregroundColor(task.status.displayColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(task.workspacePath.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)

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
            }

            Spacer()

            // File changes count
            if !task.fileChanges.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.caption)
                    Text("\(task.fileChanges.count) files changed")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }

            // Attention banner
            if task.status == .needsAttention, let reason = task.attentionReason {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(reason)
                        .font(.caption)
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }

            // Task actions
            taskActionButtons
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var taskActionButtons: some View {
        HStack(spacing: 8) {
            if task.status == .pending {
                Button("Start") {
                    Task { try? await taskManager.startTask(id: task.id) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if task.status == .working || task.status == .needsAttention {
                Button("Pause") {
                    taskManager.pauseTask(id: task.id)
                }
                .controlSize(.small)
            }

            if task.status == .paused {
                if task.agentId == nil && task.sessionId != nil {
                    Button("Re-open") {
                        Task { try? await taskManager.reopenTask(id: task.id) }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    Button("Resume") {
                        Task { try? await taskManager.resumeTask(id: task.id) }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            if task.status == .working || task.status == .needsAttention || task.status == .paused {
                Button {
                    taskManager.completeTask(id: task.id)
                } label: {
                    Label("Complete", systemImage: "checkmark.circle")
                }
                .controlSize(.small)
                .tint(.green)
            }

            if task.status.isActive || task.status == .paused {
                Button("Cancel") {
                    Task { await taskManager.cancelTask(id: task.id) }
                }
                .foregroundColor(.red)
                .controlSize(.small)
            }
        }
    }
}

/// View shown when a task is pending (not yet started)
struct TaskPendingView: View {
    let task: AgentTask
    @Environment(TaskManager.self) var taskManager
    @State private var isStarting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.circle")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text(task.name)
                .font(.title2)

            Text(task.workspacePath.path)
                .font(.caption)
                .foregroundColor(.secondary)

            if let branch = task.gitBranch {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                    Text(branch)
                }
                .foregroundColor(.purple)
            }

            if isStarting {
                ProgressView("Starting task...")
            } else {
                Button("Start Task") {
                    isStarting = true
                    errorMessage = nil
                    Task {
                        do {
                            try await taskManager.startTask(id: task.id)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        isStarting = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: 400)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// View shown when a task has completed/failed/cancelled
struct TaskCompletedView: View {
    let task: AgentTask
    @Environment(TaskManager.self) var taskManager
    @State private var isReopening: Bool = false
    @State private var reopenError: String?

    private var formattedDuration: String? {
        guard let startDate = task.startedAt ?? task.createdAt as Date?,
              let endDate = task.completedAt else { return nil }
        let duration = endDate.timeIntervalSince(startDate)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration)
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: task.status.iconName)
                .font(.system(size: 64))
                .foregroundColor(task.status.displayColor)

            Text(task.name)
                .font(.title2)

            Text("Status: \(task.status.rawValue.capitalized)")
                .font(.headline)
                .foregroundColor(task.status.displayColor)

            if !task.fileChanges.isEmpty {
                Text("\(task.fileChanges.count) file\(task.fileChanges.count == 1 ? "" : "s") changed")
                    .foregroundColor(.secondary)
            }

            if !task.messages.isEmpty {
                Text("\(task.messages.count) message\(task.messages.count == 1 ? "" : "s") in conversation")
                    .foregroundColor(.secondary)
            }

            if let completedAt = task.completedAt {
                Text("Completed: \(completedAt, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let durationString = formattedDuration {
                Text("Duration: \(durationString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if task.sessionId != nil {
                if isReopening {
                    ProgressView("Re-opening task...")
                } else {
                    Button("Re-open Task") {
                        isReopening = true
                        reopenError = nil
                        Task {
                            do {
                                try await taskManager.reopenTask(id: task.id)
                            } catch {
                                reopenError = error.localizedDescription
                            }
                            isReopening = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }

            if let error = reopenError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: 400)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let task = AgentTask(
        name: "Test Task",
        status: .pending,
        workspacePath: URL(fileURLWithPath: "/Users/test/Projects/test-project")
    )
    TaskAgentView(task: task)
        .environment(AgentManager())
        .environment(TaskManager())
        .frame(width: 800, height: 600)
}
#endif
