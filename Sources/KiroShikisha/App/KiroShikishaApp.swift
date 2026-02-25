#if os(macOS)
import SwiftUI

@main
struct KiroShikishaApp: App {
    @State private var agentManager = AgentManager()
    @State private var appStateManager = AppStateManager()
    @State private var appSettings = AppSettings()
    
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
            .preferredColorScheme(appSettings.colorScheme)
            .onAppear {
                // Sync kiro-cli path from settings to agent manager
                agentManager.kirocliPath = appSettings.expandedKirocliPath
            }
            .onChange(of: appSettings.kirocliPath) { _, _ in
                // Update agent manager when settings change
                agentManager.kirocliPath = appSettings.expandedKirocliPath
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    // App going to background - stop all agents
                    Task {
                        await agentManager.stopAllAgents()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                // App is about to quit - gracefully stop all agents
                Task {
                    await agentManager.stopAllAgents()
                }
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
            ForEach(0..<min(9, sortedAgents.count), id: \.self) { index in
                Button("Select \(sortedAgents[index].name)") {
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
