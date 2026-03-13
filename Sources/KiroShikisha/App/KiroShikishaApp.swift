#if os(macOS)
import SwiftUI

import AppKit

@main
struct KiroShikishaApp: App {

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    @State private var agentManager = AgentManager()
    @State private var appStateManager = AppStateManager()
    @State private var appSettings = AppSettings()
    @State private var taskManager = TaskManager()

    // State for commands
    @State private var showDashboard: Bool = false
    @State private var showNewTaskSheet: Bool = false

    var body: some Scene {
        WindowGroup {
            Group {
                if appSettings.hasCompletedOnboarding {
                    MainView()
                } else {
                    OnboardingView()
                }
            }
            .environment(agentManager)
            .environment(appStateManager)
            .environment(appSettings)
            .environment(taskManager)
            .preferredColorScheme(appSettings.colorScheme)
            .onAppear {
                // Sync kiro-cli path from settings to agent manager
                agentManager.kirocliPath = appSettings.expandedKirocliPath
                // Wire TaskManager to AgentManager
                taskManager.agentManager = agentManager
                // Wire TaskManager to AppStateManager for reactive persistence
                taskManager.appStateManager = appStateManager
                // Kill only our own kiro-cli processes from previous runs
                killOwnedProcesses()
                // Restore persisted tasks
                let entries = appStateManager.persistedTaskEntries
                taskManager.restoreTasks(from: entries)
                // Task-centric auto-reconnect for tasks with saved sessions
                for restoredTask in taskManager.allTasks {
                    if restoredTask.status == .paused && restoredTask.sessionId != nil {
                        Task {
                            print("[TaskReconnect] Starting reconnect for: \(restoredTask.name)")
                            do {
                                try await withThrowingTaskGroup(of: Void.self) { group in
                                    group.addTask {
                                        try await taskManager.reopenTask(id: restoredTask.id)
                                    }
                                    group.addTask {
                                        try await Task.sleep(for: .seconds(30))
                                        throw CancellationError()
                                    }
                                    // Wait for the first to complete; cancel the other
                                    try await group.next()
                                    group.cancelAll()
                                }
                                print("[TaskReconnect] Successfully reconnected: \(restoredTask.name)")
                            } catch {
                                print("[TaskReconnect] Failed for \(restoredTask.name): \(error)")
                            }
                        }
                    }
                }
                // Auto-reconnect saved sessions (workspace-based, kept for backward compatibility)
                for workspace in appStateManager.workspaces {
                    if let sessionId = appStateManager.getLastSessionForWorkspace(workspace.id) {
                        Task {
                            do {
                                let _ = try await agentManager.loadAgent(workspace: workspace, sessionId: sessionId)
                            } catch {
                                print("[AutoReconnect] Failed for \(workspace.name): \(error)")
                                appStateManager.clearSessionForWorkspace(workspace.id)
                            }
                        }
                    }
                }
            }
            .onChange(of: appSettings.kirocliPath) { _, _ in
                // Update agent manager when settings change
                agentManager.kirocliPath = appSettings.expandedKirocliPath
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                // Save active sessions for reconnect on next launch
                for agent in agentManager.getAllAgents() {
                    if let sessionId = agent.sessionId?.value {
                        appStateManager.updateSessionForWorkspace(agent.workspace.id, sessionId: sessionId)
                    }
                }
                // Flush any pending debounced task save synchronously
                appStateManager.saveImmediately()
                // Save PIDs so we can kill only our processes on next launch
                Task {
                    appStateManager.ownedProcessPids = await agentManager.collectProcessPids()
                    appStateManager.saveState()
                }
                // Kill processes
                agentManager.killAllProcesses()
            }
        }
        .commands {
            AppCommands(
                showDashboard: $showDashboard,
                showNewTaskSheet: $showNewTaskSheet,
                agentManager: agentManager,
                appStateManager: appStateManager,
                taskManager: taskManager
            )
        }

        // Settings window (Cmd+,)
        Settings {
            SettingsView()
                .environment(appSettings)
        }
    }

    /// Kill only kiro-cli processes that this app previously spawned (by saved PID)
    private func killOwnedProcesses() {
        let pids = appStateManager.ownedProcessPids
        guard !pids.isEmpty else { return }
        for pid in pids {
            // Only kill if the process is still running (kill(pid, 0) checks existence)
            if kill(pid, 0) == 0 {
                kill(pid, SIGTERM)
            }
        }
        appStateManager.ownedProcessPids = []
        appStateManager.saveState()
        if pids.contains(where: { kill($0, 0) == 0 }) {
            // Brief pause only if we actually killed something
            Thread.sleep(forTimeInterval: 0.5)
        }
    }
}

/// App-wide commands for menus and keyboard shortcuts
struct AppCommands: Commands {
    @Binding var showDashboard: Bool
    @Binding var showNewTaskSheet: Bool
    let agentManager: AgentManager
    let appStateManager: AppStateManager
    let taskManager: TaskManager

    var sortedAgents: [Agent] {
        agentManager.getAllAgents().sorted { $0.name < $1.name }
    }

    var body: some Commands {
        // File menu additions
        CommandGroup(after: .newItem) {
            Button("New Task...") {
                showNewTaskSheet = true
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
        }

        // View menu additions
        CommandGroup(after: .sidebar) {
            Button("Toggle Dashboard") {
                showDashboard.toggle()
            }
            .keyboardShortcut("d", modifiers: .command)

            Divider()

            // Agent selection shortcuts (Cmd+1 through Cmd+9)
            ForEach(Array(sortedAgents.prefix(9).enumerated()), id: \.element.id) { index, agent in
                Button("Select \(agent.name)") {
                    selectAgent(at: index)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }

        // Agent menu (kept for backward compatibility)
        CommandMenu("Agent") {
            Button("Send Prompt") {
                // Focus on prompt input - handled by responder chain
            }
            .keyboardShortcut(.return, modifiers: .command)

            Button("Cancel Current Task") {
                cancelCurrentAgentTask()
            }
            .keyboardShortcut(".", modifiers: .command)

            Divider()

            Button("Clear Chat History") {
                // Would clear current agent's history
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
        }

        // Task menu
        CommandMenu("Task") {
            Button("Pause Task") {
                pauseSelectedTask()
            }

            Button("Resume Task") {
                resumeSelectedTask()
            }

            Button("Mark Complete") {
                completeSelectedTask()
            }

            Button("Cancel Task") {
                cancelSelectedTask()
            }
        }

        // Help menu additions
        CommandGroup(replacing: .help) {
            Button("Kiro Shikisha Help") {
                // Would open help documentation
            }

            Divider()

            Button("Report an Issue...") {
                // Would open issue tracker
            }
        }
    }

    private func selectAgent(at index: Int) {
        guard index >= 0 && index < sortedAgents.count else { return }
        let agent = sortedAgents[index]
        Task { @MainActor in
            appStateManager.selectedWorkspaceId = agent.workspace.id
        }
    }

    private func cancelCurrentAgentTask() {
        // Try task-based cancellation first
        if let selectedTaskId = appStateManager.selectedTaskId,
           let task = taskManager.getTask(id: selectedTaskId),
           let agentId = task.agentId {
            Task {
                try? await agentManager.cancelPrompt(agentId: agentId)
            }
            return
        }

        // Legacy: workspace-based cancellation
        guard let selectedId = appStateManager.selectedWorkspaceId else { return }
        guard let agent = agentManager.getAllAgents().first(where: { $0.workspace.id == selectedId }) else { return }

        Task {
            try? await agentManager.cancelPrompt(agentId: agent.id)
        }
    }

    private func pauseSelectedTask() {
        guard let selectedTaskId = appStateManager.selectedTaskId else { return }
        Task { @MainActor in
            taskManager.pauseTask(id: selectedTaskId)
        }
    }

    private func resumeSelectedTask() {
        guard let selectedTaskId = appStateManager.selectedTaskId else { return }
        Task {
            try? await taskManager.resumeTask(id: selectedTaskId)
        }
    }

    private func cancelSelectedTask() {
        guard let selectedTaskId = appStateManager.selectedTaskId else { return }
        Task {
            await taskManager.cancelTask(id: selectedTaskId)
        }
    }

    private func completeSelectedTask() {
        guard let selectedTaskId = appStateManager.selectedTaskId else { return }
        Task { @MainActor in
            taskManager.completeTask(id: selectedTaskId)
        }
    }
}
#else
@main
struct KiroShikishaApp {
    static func main() {
        print("Kiro Shikisha - macOS application")
        print("Run on macOS for full GUI experience")
    }
}
#endif
