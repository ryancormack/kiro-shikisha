#if os(macOS)
import SwiftUI

/// Sidebar view showing active agents and recent workspaces
public struct SidebarView: View {
    @Binding var selectedWorkspaceId: UUID?
    @Environment(AgentManager.self) var agentManager
    
    /// Sample data for workspaces (in real app, would come from persistence)
    @State private var workspaces: [Workspace] = []
    
    private var activeAgents: [Agent] {
        agentManager.getAllAgents().filter { $0.status == .active || $0.status == .connecting }
    }
    
    private var recentWorkspaces: [Workspace] {
        // Filter out workspaces that have active agents
        let activeWorkspaceIds = Set(activeAgents.map { $0.workspace.id })
        return workspaces.filter { !activeWorkspaceIds.contains($0.id) }
            .sorted { $0.lastAccessedAt > $1.lastAccessedAt }
    }
    
    public init(selectedWorkspaceId: Binding<UUID?>) {
        self._selectedWorkspaceId = selectedWorkspaceId
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
                        WorkspaceRow(workspace: workspace, agent: nil)
                            .tag(workspace.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem {
                Button(action: addWorkspace) {
                    Label("Add Workspace", systemImage: "plus")
                }
            }
        }
    }
    
    private func addWorkspace() {
        // TODO: Implement workspace creation sheet
        // For now, this is a placeholder action
    }
}

#Preview {
    SidebarView(selectedWorkspaceId: .constant(nil))
        .environment(AgentManager())
        .frame(width: 250)
}
#endif
