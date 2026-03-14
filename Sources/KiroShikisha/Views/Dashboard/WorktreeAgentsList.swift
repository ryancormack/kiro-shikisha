#if os(macOS)
import SwiftUI

/// List view showing all tasks grouped by their workspace path
public struct WorktreeAgentsList: View {
    @Environment(TaskManager.self) var taskManager

    let onSelectTask: (AgentTask) -> Void

    public init(onSelectTask: @escaping (AgentTask) -> Void) {
        self.onSelectTask = onSelectTask
    }

    /// All tasks grouped by workspace path
    private var groupedTasks: [String: [AgentTask]] {
        var groups: [String: [AgentTask]] = [:]

        for task in taskManager.allTasks {
            let key = task.workspacePath.path

            if groups[key] == nil {
                groups[key] = []
            }
            groups[key]?.append(task)
        }

        return groups
    }

    /// Sorted list of workspace paths for consistent ordering
    private var sortedWorkspacePaths: [String] {
        groupedTasks.keys.sorted()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("All Tasks by Workspace")
                    .font(.headline)

                Spacer()

                Text("\(taskManager.allTasks.count) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            if groupedTasks.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(sortedWorkspacePaths, id: \.self) { workspacePath in
                            if let tasks = groupedTasks[workspacePath] {
                                WorkspaceTaskGroup(
                                    workspacePath: workspacePath,
                                    tasks: tasks,
                                    onSelectTask: onSelectTask
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Tasks")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Create a task to see it here")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Group of tasks belonging to the same workspace path
struct WorkspaceTaskGroup: View {
    let workspacePath: String
    let tasks: [AgentTask]
    let onSelectTask: (AgentTask) -> Void

    /// Display name from the workspace path
    private var workspaceName: String {
        URL(fileURLWithPath: workspacePath).lastPathComponent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Workspace header
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.caption)
                    .foregroundColor(.blue)

                Text(workspaceName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("(\(tasks.count) task\(tasks.count == 1 ? "" : "s"))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(tasks, id: \.id) { task in
                    TaskListRow(
                        task: task,
                        onSelect: { onSelectTask(task) }
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }
}

/// Single row for a task in the workspace-grouped list
struct TaskListRow: View {
    let task: AgentTask
    let onSelect: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Status icon
                Image(systemName: task.status.iconName)
                    .foregroundColor(task.status.displayColor)
                    .font(.caption)
                    .frame(width: 16)

                // Task info
                VStack(alignment: .leading, spacing: 1) {
                    Text(task.name)
                        .font(.caption)
                        .fontWeight(.medium)

                    HStack(spacing: 6) {
                        if let branch = task.gitBranch {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 8))
                                Text(branch)
                                    .font(.caption2)
                            }
                            .foregroundColor(.purple)
                        }

                        Text(task.status.rawValue.capitalized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium)
                    .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    WorktreeAgentsList(
        onSelectTask: { task in
            print("Selected: \(task.name)")
        }
    )
    .environment(TaskManager())
    .frame(width: 400, height: 500)
}
#endif
