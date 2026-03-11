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
    @State private var showNewWorkspaceSheet: Bool = false
    
    // Environment for scene lifecycle
    @Environment(\.scenePhase) var scenePhase
    
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
                // Kill only our own kiro-cli processes from previous runs
                killOwnedProcesses()
                // Auto-reconnect saved sessions
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
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    // App going to background - only stop agents on macOS if app is actually being hidden
                    // Don't stop on sheet dismissals which can briefly trigger background phase
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                // Save active sessions and PIDs for reconnect on next launch
                for agent in agentManager.getAllAgents() {
                    if let sessionId = agent.sessionId?.value {
                        appStateManager.updateSessionForWorkspace(agent.workspace.id, sessionId: sessionId)
                    }
                }
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
                showNewWorkspaceSheet: $showNewWorkspaceSheet,
                agentManager: agentManager,
                appStateManager: appStateManager
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
    @Binding var showNewWorkspaceSheet: Bool
    let agentManager: AgentManager
    let appStateManager: AppStateManager
    
    var sortedAgents: [Agent] {
        agentManager.getAllAgents().sorted { $0.name < $1.name }
    }
    
    var body: some Commands {
        // File menu additions
        CommandGroup(after: .newItem) {
            Button("New Workspace...") {
                showNewWorkspaceSheet = true
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
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
        
        // Agent menu
        CommandMenu("Agent") {
            Button("Send Prompt") {
                // Focus on prompt input - handled by responder chain
            }
            .keyboardShortcut(.return, modifiers: .command)
            
            Button("Cancel Current Task") {
                cancelCurrentTask()
            }
            .keyboardShortcut(".", modifiers: .command)
            
            Divider()
            
            Button("Clear Chat History") {
                // Would clear current agent's history
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
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
    
    private func cancelCurrentTask() {
        guard let selectedId = appStateManager.selectedWorkspaceId else { return }
        guard let agent = agentManager.getAllAgents().first(where: { $0.workspace.id == selectedId }) else { return }
        
        Task {
            try? await agentManager.cancelPrompt(agentId: agent.id)
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
