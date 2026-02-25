#if os(macOS)
import SwiftUI

/// Sidebar view showing active agents and recent workspaces
public struct SidebarView: View {
    @Binding var selectedWorkspaceId: UUID?
    @Environment(AgentManager.self) var agentManager
    
    /// Workspaces from AppStateManager
    let workspaces: [Workspace]
    
    /// Callback when a workspace is created
    var onAddWorkspace: ((Workspace) -> Void)?
    
    /// Callback when a workspace should be removed
    var onRemoveWorkspace: ((UUID) -> Void)?
    
    /// Whether the new workspace sheet is showing
    @State private var showingNewWorkspace: Bool = false
    
    /// Workspace currently showing session history
    @State private var sessionHistoryWorkspace: Workspace?
    
    /// Session counts for each workspace path
    @State private var sessionCounts: [String: Int] = [:]
    
    /// Session storage for loading session data
    private let sessionStorage = SessionStorage()
    
    /// Callback when a session should be resumed
    var onResumeSession: ((Workspace, String) -> Void)?
    
    private var activeAgents: [Agent] {
        agentManager.getAllAgents().filter { $0.status == .active || $0.status == .connecting }
    }
    
    private var recentWorkspaces: [Workspace] {
        // Filter out workspaces that have active agents
        let activeWorkspaceIds = Set(activeAgents.map { $0.workspace.id })
        return workspaces.filter { !activeWorkspaceIds.contains($0.id) }
            .sorted { $0.lastAccessedAt > $1.lastAccessedAt }
    }
    
    public init(
        selectedWorkspaceId: Binding<UUID?>,
        workspaces: [Workspace] = [],
        onAddWorkspace: ((Workspace) -> Void)? = nil,
        onRemoveWorkspace: ((UUID) -> Void)? = nil,
        onResumeSession: ((Workspace, String) -> Void)? = nil
    ) {
        self._selectedWorkspaceId = selectedWorkspaceId
        self.workspaces = workspaces
        self.onAddWorkspace = onAddWorkspace
        self.onRemoveWorkspace = onRemoveWorkspace
        self.onResumeSession = onResumeSession
    }
    
    public var body: some View {
        List(selection: $selectedWorkspaceId) {
            Section("Active Agents") {
                if activeAgents.isEmpty {
                    Text("No active agents")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(activeAgents) { agent in
                        WorkspaceRow(workspace: agent.workspace, agent: agent)
                            .tag(agent.workspace.id)
                    }
                }
            }
            
            Section("Recent Workspaces") {
                if recentWorkspaces.isEmpty {
                    Text("No recent workspaces")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(recentWorkspaces) { workspace in
                        WorkspaceRow(
                            workspace: workspace,
                            agent: nil,
                            sessionCount: sessionCounts[workspace.path.path],
                            onShowSessionHistory: {
                                sessionHistoryWorkspace = workspace
                            }
                        )
                        .tag(workspace.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem {
                NewWorkspaceButton(showingSheet: $showingNewWorkspace)
            }
        }
        .sheet(isPresented: $showingNewWorkspace) {
            NewWorkspaceSheet { workspace in
                onAddWorkspace?(workspace)
                selectedWorkspaceId = workspace.id
                // Refresh session counts after adding workspace
                refreshSessionCounts()
            }
        }
        .sheet(item: $sessionHistoryWorkspace) { workspace in
            SessionHistorySheet(
                workspace: workspace,
                sessionStorage: sessionStorage,
                onResumeSession: { sessionId in
                    sessionHistoryWorkspace = nil
                    onResumeSession?(workspace, sessionId)
                }
            )
        }
        .onAppear {
            refreshSessionCounts()
        }
        .onChange(of: workspaces) { _, _ in
            refreshSessionCounts()
        }
    }
    
    /// Refresh session counts for all workspaces
    private func refreshSessionCounts() {
        Task {
            var counts: [String: Int] = [:]
            for workspace in workspaces {
                let sessions = sessionStorage.getSessionsForWorkspace(path: workspace.path)
                counts[workspace.path.path] = sessions.count
            }
            await MainActor.run {
                sessionCounts = counts
            }
        }
    }
}

/// Sheet wrapper for SessionHistoryView
private struct SessionHistorySheet: View {
    let workspace: Workspace
    let sessionStorage: SessionStorage
    let onResumeSession: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            SessionHistoryView(
                workspacePath: workspace.path,
                sessionStorage: sessionStorage,
                onSelectSession: onResumeSession
            )
            .navigationTitle("Session History")
            .navigationSubtitle(workspace.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    SidebarView(
        selectedWorkspaceId: .constant(nil),
        workspaces: []
    )
    .environment(AgentManager())
    .frame(width: 250)
}
#endif
