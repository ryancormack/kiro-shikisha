#if os(macOS)
import SwiftUI

/// Main application view with sidebar navigation and task detail view
public struct MainView: View {
    @Environment(AgentManager.self) var agentManager
    @Environment(AppStateManager.self) var appStateManager
    @Environment(TaskManager.self) var taskManager

    @State private var showDashboard: Bool = false
    @State private var showNewTaskSheet: Bool = false

    /// The currently selected task, looked up from taskManager
    private var selectedTask: AgentTask? {
        guard let taskId = appStateManager.selectedTaskId else { return nil }
        return taskManager.getTask(id: taskId)
    }

    /// The agent for the selected task, if any
    private var selectedAgent: Agent? {
        guard let task = selectedTask, let agentId = task.agentId else { return nil }
        return agentManager.getAgent(id: agentId)
    }

    /// Legacy: selected workspace for backward compatibility
    private var selectedWorkspace: Workspace? {
        guard let workspaceId = appStateManager.selectedWorkspaceId else { return nil }
        return appStateManager.workspaces.first { $0.id == workspaceId }
    }

    public init() {}

    public var body: some View {
        @Bindable var stateManager = appStateManager

        NavigationSplitView {
            SidebarView(
                selectedTaskId: $stateManager.selectedTaskId,
                onCreateTask: {
                    showNewTaskSheet = true
                },
                onDeleteTask: { id in
                    Task { await taskManager.deleteTask(id: id) }
                    if appStateManager.selectedTaskId == id {
                        appStateManager.selectedTaskId = nil
                    }
                }
            )
        } detail: {
            if showDashboard {
                DashboardView(
                    onSelectTask: { task in
                        stateManager.selectedTaskId = task.id
                        showDashboard = false
                    },
                    onNewTask: {
                        showNewTaskSheet = true
                    }
                )
            } else if let task = selectedTask {
                TaskAgentView(task: task)
            } else if let workspace = selectedWorkspace {
                WorkspaceReadyView(workspace: workspace, agentManager: agentManager)
            } else {
                PlaceholderView()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    Button {
                        showNewTaskSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .help("New Task")
                    }

                    Button {
                        showDashboard.toggle()
                    } label: {
                        Image(systemName: showDashboard ? "person.fill" : "rectangle.grid.2x2")
                            .help(showDashboard ? "Show Single Task" : "Show Dashboard")
                    }
                }
            }
        }
        .onChange(of: appStateManager.selectedTaskId) { _, _ in
            appStateManager.saveState()
        }
        .sheet(isPresented: $showNewTaskSheet) {
            NewTaskSheet { request in
                let task = taskManager.createTask(from: request)
                appStateManager.selectTask(task.id)
                showNewTaskSheet = false
            }
        }
    }
}

/// Commands for keyboard shortcuts
public struct MainViewCommands: Commands {
    @Binding var showDashboard: Bool
    @Binding var showNewTaskSheet: Bool
    let sortedAgents: [Agent]
    let onSelectAgent: (Int) -> Void

    public var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Task...") {
                showNewTaskSheet = true
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
        }

        CommandGroup(after: .sidebar) {
            Button("Toggle Dashboard") {
                showDashboard.toggle()
            }
            .keyboardShortcut("d", modifiers: .command)

            Divider()

            // Agent selection shortcuts (Cmd+1 through Cmd+9)
            ForEach(Array(sortedAgents.prefix(9).enumerated()), id: \.element.id) { index, agent in
                Button("Select \(agent.name)") {
                    onSelectAgent(index)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }
    }
}

/// Sheet for creating a new agent in a worktree (legacy, kept for backward compatibility)
struct NewWorktreeAgentSheet: View {
    @Environment(AgentManager.self) var agentManager
    @Environment(\.dismiss) var dismiss

    let workspaces: [Workspace]
    let onDismiss: () -> Void

    @State private var selectedWorkspace: Workspace?
    @State private var branchName: String = ""
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?

    /// Only workspaces that are not worktrees themselves
    private var mainWorkspaces: [Workspace] {
        workspaces.filter { $0.sourceWorkspaceId == nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("New Worktree Agent")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            Divider()

            // Workspace selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Source Workspace")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Picker("Select workspace:", selection: $selectedWorkspace) {
                    Text("Select...").tag(nil as Workspace?)
                    ForEach(mainWorkspaces) { workspace in
                        Text(workspace.name).tag(workspace as Workspace?)
                    }
                }
                .pickerStyle(.menu)
            }

            // Branch name
            VStack(alignment: .leading, spacing: 8) {
                Text("Branch Name")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("feature/my-feature", text: $branchName)
                    .textFieldStyle(.roundedBorder)

                Text("A new git worktree will be created with this branch")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Spacer()

            // Actions
            HStack {
                Spacer()

                Button("Create & Start Agent") {
                    createWorktreeAgent()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedWorkspace == nil || branchName.isEmpty || isCreating)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }

    private func createWorktreeAgent() {
        guard let workspace = selectedWorkspace else { return }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                _ = try await agentManager.startAgentInWorktree(
                    sourceWorkspace: workspace,
                    branchName: branchName
                )
                onDismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
}

/// View shown when a workspace is selected but no agent is running
struct WorkspaceReadyView: View {
    let workspace: Workspace
    let agentManager: AgentManager
    @State private var isStarting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.circle")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text(workspace.name)
                .font(.title2)

            Text(workspace.path.path)
                .font(.caption)
                .foregroundColor(.secondary)

            if isStarting {
                ProgressView("Connecting...")
            } else {
                Button("Start Agent") {
                    isStarting = true
                    errorMessage = nil
                    Task {
                        do {
                            let _ = try await agentManager.startAgent(workspace: workspace)
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

/// Placeholder view shown when no task is selected
struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Select a Task")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Create a new task or select an existing task from the sidebar")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MainView()
        .environment(AgentManager())
        .environment(AppStateManager())
        .environment(TaskManager())
}
#endif
