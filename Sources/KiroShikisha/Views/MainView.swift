#if os(macOS)
import SwiftUI

/// Main application view with sidebar navigation and agent detail view
public struct MainView: View {
    @Environment(AgentManager.self) var agentManager
    @Environment(AppStateManager.self) var appStateManager
    
    @State private var showDashboard: Bool = false
    @State private var showNewWorkspaceSheet: Bool = false
    @State private var showNewWorktreeAgentSheet: Bool = false
    
    private var selectedAgent: Agent? {
        guard let workspaceId = appStateManager.selectedWorkspaceId else { return nil }
        return agentManager.getAllAgents().first { $0.workspace.id == workspaceId }
    }
    
    private var selectedWorkspace: Workspace? {
        guard let workspaceId = appStateManager.selectedWorkspaceId else { return nil }
        return appStateManager.workspaces.first { $0.id == workspaceId }
    }
    
    /// Sorted list of agents for keyboard shortcut selection
    private var sortedAgents: [Agent] {
        agentManager.getAllAgents().sorted { $0.name < $1.name }
    }
    
    public init() {}
    
    public var body: some View {
        @Bindable var stateManager = appStateManager
        
        NavigationSplitView {
            SidebarView(
                selectedWorkspaceId: $stateManager.selectedWorkspaceId,
                workspaces: appStateManager.workspaces,
                onAddWorkspace: { workspace in
                    appStateManager.addWorkspace(workspace)
                },
                onRemoveWorkspace: { id in
                    appStateManager.removeWorkspace(id: id)
                },
                onResumeSession: { workspace, sessionId in
                    appStateManager.updateSessionForWorkspace(workspace.id, sessionId: sessionId)
                    appStateManager.selectedWorkspaceId = workspace.id
                    Task {
                        do {
                            let _ = try await agentManager.loadAgent(workspace: workspace, sessionId: sessionId)
                        } catch {
                            print("[Resume] Failed to load session \(sessionId): \(error)")
                        }
                    }
                }
            )
        } detail: {
            if showDashboard {
                DashboardView(
                    onSelectAgent: { agent in
                        // Switch to agent detail view when selecting from dashboard
                        stateManager.selectedWorkspaceId = agent.workspace.id
                        showDashboard = false
                    },
                    onNewWorktreeAgent: {
                        showNewWorktreeAgentSheet = true
                    }
                )
            } else if let agent = selectedAgent {
                AgentView(agent: agent)
            } else if let workspace = selectedWorkspace {
                WorkspaceReadyView(workspace: workspace, agentManager: agentManager)
            } else {
                PlaceholderView()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showDashboard.toggle()
                } label: {
                    Image(systemName: showDashboard ? "person.fill" : "rectangle.grid.2x2")
                        .help(showDashboard ? "Show Single Agent" : "Show Dashboard")
                }
            }
        }
        .onChange(of: appStateManager.selectedWorkspaceId) { _, newValue in
            appStateManager.saveState()
        }
        // Keyboard shortcuts
        .keyboardShortcut("d", modifiers: .command)  // Cmd+D: Toggle dashboard
        .sheet(isPresented: $showNewWorkspaceSheet) {
            NewWorkspaceSheet { workspace in
                appStateManager.addWorkspace(workspace)
                showNewWorkspaceSheet = false
            }
        }
        .sheet(isPresented: $showNewWorktreeAgentSheet) {
            NewWorktreeAgentSheet(
                workspaces: appStateManager.workspaces,
                onDismiss: { showNewWorktreeAgentSheet = false }
            )
        }
    }
    
    /// Selects an agent by index (0-8 for Cmd+1 through Cmd+9)
    private func selectAgent(at index: Int) {
        guard index >= 0 && index < sortedAgents.count else { return }
        let agent = sortedAgents[index]
        appStateManager.selectedWorkspaceId = agent.workspace.id
        showDashboard = false
    }
}

/// Commands for keyboard shortcuts
public struct MainViewCommands: Commands {
    @Binding var showDashboard: Bool
    @Binding var showNewWorkspaceSheet: Bool
    @Binding var showNewWorktreeAgentSheet: Bool
    let sortedAgents: [Agent]
    let onSelectAgent: (Int) -> Void
    
    public var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Workspace") {
                showNewWorkspaceSheet = true
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Button("New Worktree Agent") {
                showNewWorktreeAgentSheet = true
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
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

/// Sheet for creating a new agent in a worktree
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
                ProgressView("Connecting…")
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

/// Placeholder view shown when no agent is selected
struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("Select a Workspace")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Choose a workspace from the sidebar to start chatting with an agent")
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
}
#endif
