#if os(macOS)
import SwiftUI

/// Dashboard view showing all active tasks in a grid layout
public struct DashboardView: View {
    @Environment(AgentManager.self) var agentManager
    @Environment(TaskManager.self) var taskManager

    let onSelectTask: (AgentTask) -> Void
    var onNewTask: (() -> Void)?

    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 450), spacing: 16)
    ]

    public init(
        onSelectTask: @escaping (AgentTask) -> Void,
        onNewTask: (() -> Void)? = nil
    ) {
        self.onSelectTask = onSelectTask
        self.onNewTask = onNewTask
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header with Quick Actions
            HStack {
                Text("Tasks Overview")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                QuickActionsView(
                    onCancelAll: cancelAllTasks,
                    onRefreshAll: refreshAllAgents,
                    onSummarizeAll: summarizeAllTasks,
                    onNewTask: onNewTask
                )
            }
            .padding()

            Divider()

            // Content
            if taskManager.activeTasks.isEmpty && taskManager.tasksNeedingAttention.isEmpty {
                emptyStateView
            } else {
                HSplitView {
                    // Tasks content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Needs Attention section
                            if !taskManager.tasksNeedingAttention.isEmpty {
                                attentionSection
                            }

                            // Active tasks grid
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(taskManager.activeTasks, id: \.id) { task in
                                    TaskCard(task: task) {
                                        onSelectTask(task)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .frame(minWidth: 400)

                    // Activity feed
                    ActivityFeed(events: agentManager.activityEvents)
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Needs Attention")
                    .font(.headline)
                    .foregroundColor(.orange)
                Text("(\(taskManager.tasksNeedingAttention.count))")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            VStack(spacing: 8) {
                ForEach(taskManager.tasksNeedingAttention, id: \.id) { task in
                    TaskCard(task: task) {
                        onSelectTask(task)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: DesignConstants.cardCornerRadius)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Active Tasks")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Create a new task to begin working with an agent")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            // Add button for new task in empty state
            if let onNewTask = onNewTask {
                Button(action: onNewTask) {
                    Label("Create New Task", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, DesignConstants.spacingSM)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Cancels all active tasks
    private func cancelAllTasks() async {
        let taskIds = taskManager.activeTasks.map { $0.id }
        for id in taskIds {
            await taskManager.cancelTask(id: id)
        }
    }

    /// Summarizes all active tasks
    private func summarizeAllTasks() async {
        _ = await taskManager.summarizeAllActiveTasks()
    }

    /// Refreshes all agents (reconnects them)
    private func refreshAllAgents() async {
        // Placeholder that would reconnect agents
        try? await Task.sleep(for: .milliseconds(500))
    }
}

#Preview {
    DashboardView(
        onSelectTask: { task in
            print("Selected task: \(task.name)")
        },
        onNewTask: {
            print("New task requested")
        }
    )
    .environment(AgentManager())
    .environment(TaskManager())
    .frame(width: 900, height: 600)
}
#endif
