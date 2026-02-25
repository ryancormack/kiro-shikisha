#if os(macOS)
import SwiftUI

/// Main application view with sidebar navigation and agent detail view
public struct MainView: View {
    @Environment(AgentManager.self) var agentManager
    @Environment(AppStateManager.self) var appStateManager
    
    @State private var showDashboard: Bool = false
    
    private var selectedAgent: Agent? {
        guard let workspaceId = appStateManager.selectedWorkspaceId else { return nil }
        return agentManager.getAllAgents().first { $0.workspace.id == workspaceId }
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
                }
            )
        } detail: {
            if showDashboard {
                DashboardView { agent in
                    // Switch to agent detail view when selecting from dashboard
                    stateManager.selectedWorkspaceId = agent.workspace.id
                    showDashboard = false
                }
            } else if let agent = selectedAgent {
                AgentView(agent: agent)
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
            // Save state when selection changes
            appStateManager.saveState()
        }
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
