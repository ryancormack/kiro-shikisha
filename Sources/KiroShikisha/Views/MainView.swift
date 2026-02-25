#if os(macOS)
import SwiftUI

/// Main application view with sidebar navigation and agent detail view
public struct MainView: View {
    @State private var selectedWorkspaceId: UUID?
    @Environment(AgentManager.self) var agentManager
    
    private var selectedAgent: Agent? {
        guard let workspaceId = selectedWorkspaceId else { return nil }
        return agentManager.getAllAgents().first { $0.workspace.id == workspaceId }
    }
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            SidebarView(selectedWorkspaceId: $selectedWorkspaceId)
        } detail: {
            if let agent = selectedAgent {
                AgentView(agent: agent)
            } else {
                PlaceholderView()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
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

/// Temporary stub for AgentView until it's fully implemented in a later step
struct AgentView: View {
    let agent: Agent
    
    var body: some View {
        VStack {
            Text("Agent: \(agent.name)")
                .font(.headline)
            
            Text("Workspace: \(agent.workspace.path.path)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            StatusBadge(status: agent.status, showLabel: true)
                .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MainView()
        .environment(AgentManager())
}
#endif
