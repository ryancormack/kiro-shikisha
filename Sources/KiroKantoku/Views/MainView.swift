#if os(macOS)
import SwiftUI

/// Main application view with sidebar navigation and task detail view
public struct MainView: View {
    @Environment(AgentManager.self) var agentManager
    @Environment(AppStateManager.self) var appStateManager
    @Environment(TaskManager.self) var taskManager
    @Environment(AppSettings.self) var appSettings

    @State private var showPixelOffice: Bool = false

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


    public init() {}

    public var body: some View {
        @Bindable var stateManager = appStateManager

        ErrorBannerContainer(errors: $stateManager.globalErrors) {
        NavigationSplitView {
            SidebarView(
                selectedTaskId: $stateManager.selectedTaskId,
                onCreateTask: {
                    stateManager.showNewTaskSheet = true
                },
                onBrowseSessions: {
                    stateManager.showLoadSessionSheet = true
                },
                onDeleteTask: { id in
                    Task { await taskManager.deleteTask(id: id) }
                    if appStateManager.selectedTaskId == id {
                        appStateManager.selectedTaskId = nil
                    }
                }
            )
        } detail: {
            if stateManager.showDashboard {
                DashboardView(
                    onSelectTask: { task in
                        stateManager.selectedTaskId = task.id
                        stateManager.showDashboard = false
                    },
                    onNewTask: {
                        stateManager.showNewTaskSheet = true
                    }
                )
            } else if let task = selectedTask {
                TaskAgentView(task: task)
            } else {
                PlaceholderView()
            }
        }
        .frame(minWidth: 900, minHeight: 650)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    Button {
                        stateManager.showNewTaskSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .help("New Task")
                    }

                    Button {
                        stateManager.showLoadSessionSheet = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .help("Load Session…")
                    }

                    Button {
                        stateManager.showDashboard.toggle()
                    } label: {
                        Image(systemName: stateManager.showDashboard ? "person.fill" : "rectangle.grid.2x2")
                            .help(stateManager.showDashboard ? "Show Single Task" : "Show Dashboard")
                    }

                    if appSettings.showPixelOffice {
                        Button {
                            showPixelOffice.toggle()
                        } label: {
                            Image(systemName: showPixelOffice ? "building.2.fill" : "building.2")
                                .help(showPixelOffice ? "Hide Pixel Office" : "Show Pixel Office")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $stateManager.showNewTaskSheet) {
            NewTaskSheet(
                onCreate: { request in
                    let task = taskManager.createTask(from: request)
                    appStateManager.selectTask(task.id)
                    stateManager.showDashboard = false
                    if request.startImmediately {
                        Task { try? await taskManager.startTask(id: task.id) }
                    }
                    stateManager.showNewTaskSheet = false
                },
                onResumeSession: { sessionId, cwd in
                    Task {
                        if let task = try? await taskManager.loadExternalSession(sessionId: sessionId, cwd: cwd) {
                            appStateManager.selectTask(task.id)
                            stateManager.showDashboard = false
                        }
                    }
                    stateManager.showNewTaskSheet = false
                }
            )
        }
        .sheet(isPresented: $showPixelOffice) {
            PixelOfficeView()
                .frame(minWidth: 700, minHeight: 520)
        }
        .sheet(isPresented: $stateManager.showLoadSessionSheet) {
            AllSessionsView { sessionId, cwd in
                Task {
                    if let task = try? await taskManager.loadExternalSession(sessionId: sessionId, cwd: cwd) {
                        appStateManager.selectTask(task.id)
                        stateManager.showDashboard = false
                    }
                }
            }
        }
        } // ErrorBannerContainer
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
        .environment(AppSettings())
}
#endif
