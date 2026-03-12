#if os(macOS)
import SwiftUI

/// Sidebar view showing active tasks, tasks needing attention, and task history
public struct SidebarView: View {
    @Binding var selectedTaskId: UUID?
    @Environment(AgentManager.self) var agentManager
    @Environment(TaskManager.self) var taskManager

    /// Callback when a task should be created
    var onCreateTask: (() -> Void)?

    /// Callback when a task should be deleted
    var onDeleteTask: ((UUID) -> Void)?

    /// Task pending delete confirmation
    @State private var taskToDelete: AgentTask?

    /// Whether the new task sheet is showing
    @State private var showingNewTask: Bool = false

    private var sortedActiveTasks: [AgentTask] {
        taskManager.activeTasks.sorted {
            ($0.lastActivityAt ?? $0.createdAt) > ($1.lastActivityAt ?? $1.createdAt)
        }
    }

    private var sortedTaskHistory: [AgentTask] {
        Array(
            taskManager.completedTasks.sorted {
                ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt)
            }
            .prefix(20)
        )
    }

    private var pausedTasks: [AgentTask] {
        taskManager.allTasks.filter { $0.status == .paused }
            .sorted { ($0.lastActivityAt ?? $0.createdAt) > ($1.lastActivityAt ?? $1.createdAt) }
    }

    public init(
        selectedTaskId: Binding<UUID?>,
        onCreateTask: (() -> Void)? = nil,
        onDeleteTask: ((UUID) -> Void)? = nil
    ) {
        self._selectedTaskId = selectedTaskId
        self.onCreateTask = onCreateTask
        self.onDeleteTask = onDeleteTask
    }

    public var body: some View {
        List(selection: $selectedTaskId) {
            Section("Active Tasks") {
                if sortedActiveTasks.isEmpty {
                    Text("No active tasks")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(sortedActiveTasks) { task in
                        TaskRow(task: task)
                            .tag(task.id)
                            .contextMenu {
                                Button("Mark Complete") {
                                    taskManager.completeTask(id: task.id)
                                }
                                Button("Pause Task") {
                                    taskManager.pauseTask(id: task.id)
                                }
                                Button("Cancel Task", role: .destructive) {
                                    Task { await taskManager.cancelTask(id: task.id) }
                                }
                            }
                    }
                }
            }

            if !taskManager.tasksNeedingAttention.isEmpty {
                Section {
                    ForEach(taskManager.tasksNeedingAttention) { task in
                        TaskRow(task: task)
                            .tag(task.id)
                            .contextMenu {
                                Button("Mark Complete") {
                                    taskManager.completeTask(id: task.id)
                                }
                                Button("Pause Task") {
                                    taskManager.pauseTask(id: task.id)
                                }
                                Button("Cancel Task", role: .destructive) {
                                    Task { await taskManager.cancelTask(id: task.id) }
                                }
                            }
                    }
                } header: {
                    Label("Needs Attention", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            }

            if !pausedTasks.isEmpty {
                Section("Paused Tasks") {
                    ForEach(pausedTasks) { task in
                        TaskRow(task: task)
                            .tag(task.id)
                            .contextMenu {
                                if task.agentId == nil && task.sessionId != nil {
                                    Button("Re-open") {
                                        Task { try? await taskManager.reopenTask(id: task.id) }
                                    }
                                } else {
                                    Button("Resume") {
                                        Task { try? await taskManager.resumeTask(id: task.id) }
                                    }
                                }
                                Button("Mark Complete") {
                                    taskManager.completeTask(id: task.id)
                                }
                                Button("Cancel Task", role: .destructive) {
                                    Task { await taskManager.cancelTask(id: task.id) }
                                }
                            }
                    }
                }
            }

            Section("Task History") {
                if sortedTaskHistory.isEmpty {
                    Text("No completed tasks")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(sortedTaskHistory) { task in
                        TaskRow(task: task)
                            .tag(task.id)
                            .contextMenu {
                                if task.sessionId != nil {
                                    Button("Re-open") {
                                        Task { try? await taskManager.reopenTask(id: task.id) }
                                    }
                                }
                                Button("Delete Task", role: .destructive) {
                                    taskToDelete = task
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem {
                NewTaskButton(showingSheet: $showingNewTask)
            }
        }
        .onChange(of: showingNewTask) { _, newValue in
            if newValue {
                onCreateTask?()
                showingNewTask = false
            }
        }
        .alert("Delete Task?", isPresented: Binding(
            get: { taskToDelete != nil },
            set: { if !$0 { taskToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { taskToDelete = nil }
            Button("Delete", role: .destructive) {
                if let task = taskToDelete {
                    onDeleteTask?(task.id)
                    taskToDelete = nil
                }
            }
        } message: {
            if let task = taskToDelete {
                Text("Delete \"\(task.name)\"? This action cannot be undone.")
            }
        }
    }
}

#Preview {
    SidebarView(
        selectedTaskId: .constant(nil)
    )
    .environment(AgentManager())
    .environment(TaskManager())
    .frame(width: 250)
}
#endif
