#if os(macOS)
import SwiftUI

/// List view showing all agents grouped by their source workspace
/// Useful for overview of multi-worktree workflows
public struct WorktreeAgentsList: View {
    @Environment(AgentManager.self) var agentManager
    
    let onSelectAgent: (Agent) -> Void
    
    public init(onSelectAgent: @escaping (Agent) -> Void) {
        self.onSelectAgent = onSelectAgent
    }
    
    /// All agents grouped by their source workspace ID
    private var groupedAgents: [UUID: [Agent]] {
        let allAgents = agentManager.getAllAgents()
        var groups: [UUID: [Agent]] = [:]
        
        for agent in allAgents {
            // Get the source workspace ID (either the workspace ID if main, or sourceWorkspaceId if worktree)
            let sourceId = agent.workspace.sourceWorkspaceId ?? agent.workspace.id
            
            if groups[sourceId] == nil {
                groups[sourceId] = []
            }
            groups[sourceId]?.append(agent)
        }
        
        return groups
    }
    
    /// Sorted list of source workspace IDs for consistent ordering
    private var sortedWorkspaceIds: [UUID] {
        groupedAgents.keys.sorted { id1, id2 in
            // Sort by the first agent's name in each group
            let name1 = groupedAgents[id1]?.first?.workspace.name ?? ""
            let name2 = groupedAgents[id2]?.first?.workspace.name ?? ""
            return name1 < name2
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("All Agents by Workspace")
                    .font(.headline)
                
                Spacer()
                
                Text("\(agentManager.getAllAgents().count) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            Divider()
            
            if groupedAgents.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(sortedWorkspaceIds, id: \.self) { workspaceId in
                            if let agents = groupedAgents[workspaceId] {
                                WorkspaceAgentGroup(
                                    agents: agents,
                                    onSelectAgent: onSelectAgent
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Agents Running")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Start agents from a workspace to see them here")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Group of agents belonging to the same source workspace
struct WorkspaceAgentGroup: View {
    let agents: [Agent]
    let onSelectAgent: (Agent) -> Void
    
    /// Name of the source workspace
    private var workspaceName: String {
        // Find the main workspace agent or use the first agent's workspace name
        if let mainAgent = agents.first(where: { $0.workspace.sourceWorkspaceId == nil }) {
            return mainAgent.workspace.name
        }
        return agents.first?.workspace.name ?? "Unknown"
    }
    
    /// Main workspace agent (if any)
    private var mainAgent: Agent? {
        agents.first { $0.workspace.sourceWorkspaceId == nil }
    }
    
    /// Worktree agents
    private var worktreeAgents: [Agent] {
        agents.filter { $0.workspace.sourceWorkspaceId != nil }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Workspace header
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text(workspaceName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("(\(agents.count) agent\(agents.count == 1 ? "" : "s"))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Main workspace agent
                if let main = mainAgent {
                    AgentListRow(
                        agent: main,
                        isWorktree: false,
                        onSelect: { onSelectAgent(main) }
                    )
                }
                
                // Worktree agents
                ForEach(worktreeAgents, id: \.id) { agent in
                    AgentListRow(
                        agent: agent,
                        isWorktree: true,
                        onSelect: { onSelectAgent(agent) }
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }
}

/// Single row for an agent in the list
struct AgentListRow: View {
    let agent: Agent
    let isWorktree: Bool
    let onSelect: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Indent worktrees
                if isWorktree {
                    Spacer()
                        .frame(width: 16)
                }
                
                // Status dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                
                // Worktree icon
                if isWorktree {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                
                // Agent info
                VStack(alignment: .leading, spacing: 1) {
                    Text(agent.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 6) {
                        if let branch = agent.workspace.gitBranch {
                            Text(branch)
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                        
                        Text(statusText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var statusColor: Color {
        switch agent.status {
        case .active: return .green
        case .connecting: return .orange
        case .idle: return .gray
        case .error: return .red
        }
    }
    
    private var statusText: String {
        switch agent.status {
        case .active: return "Active"
        case .connecting: return "Connecting..."
        case .idle: return "Idle"
        case .error: return "Error"
        }
    }
}

#Preview {
    WorktreeAgentsList(
        onSelectAgent: { agent in
            print("Selected: \(agent.name)")
        }
    )
    .environment(AgentManager())
    .frame(width: 400, height: 500)
}
#endif
