#if os(macOS)
import SwiftUI

/// View showing all agents running in a workspace and its worktrees
public struct WorkspaceAgentsView: View {
    @Environment(AgentManager.self) var agentManager
    
    let workspace: Workspace
    let onSelectAgent: (Agent) -> Void
    let onStartNewWorktreeAgent: () -> Void
    
    public init(
        workspace: Workspace,
        onSelectAgent: @escaping (Agent) -> Void,
        onStartNewWorktreeAgent: @escaping () -> Void
    ) {
        self.workspace = workspace
        self.onSelectAgent = onSelectAgent
        self.onStartNewWorktreeAgent = onStartNewWorktreeAgent
    }
    
    /// All agents for this workspace including worktrees
    private var allAgents: [Agent] {
        agentManager.getAgentsForWorkspace(workspace.id)
    }
    
    /// Agents in the main workspace
    private var mainWorkspaceAgents: [Agent] {
        allAgents.filter { $0.workspace.id == workspace.id }
    }
    
    /// Agents in linked worktrees
    private var worktreeAgents: [Agent] {
        allAgents.filter { $0.workspace.sourceWorkspaceId == workspace.id }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Agents in \(workspace.name)")
                        .font(.headline)
                    Text("\(allAgents.count) running")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onStartNewWorktreeAgent) {
                    Label("New Worktree Agent", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.top)
            
            Divider()
            
            if allAgents.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Main workspace section
                        if !mainWorkspaceAgents.isEmpty {
                            agentSection(
                                title: "Main Workspace",
                                agents: mainWorkspaceAgents,
                                icon: "folder.fill"
                            )
                        }
                        
                        // Worktree agents section
                        if !worktreeAgents.isEmpty {
                            agentSection(
                                title: "Worktrees",
                                agents: worktreeAgents,
                                icon: "arrow.triangle.branch"
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    @ViewBuilder
    private func agentSection(title: String, agents: [Agent], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            
            ForEach(agents, id: \.id) { agent in
                WorkspaceAgentRow(agent: agent, onSelect: { onSelectAgent(agent) })
            }
        }
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
            
            Text("Start a new agent to work on this workspace")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onStartNewWorktreeAgent) {
                Label("New Worktree Agent", systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Row displaying a single agent in the workspace agents list
struct WorkspaceAgentRow: View {
    let agent: Agent
    let onSelect: () -> Void
    
    @State private var isHovered: Bool = false
    
    /// Time since last activity
    private var lastActivityText: String {
        if agent.status == .active {
            return "Active now"
        }
        // In a real implementation, we'd track last message timestamp
        return "Idle"
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                // Agent info
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        // Branch/worktree info
                        if let branch = agent.workspace.gitBranch {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.caption2)
                                Text(branch)
                                    .font(.caption2)
                            }
                            .foregroundColor(.purple)
                        }
                        
                        // Last activity
                        Text(lastActivityText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Message count badge
                if !agent.messages.isEmpty {
                    Text("\(agent.messages.count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusSmall))
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium)
                    .fill(isHovered ? Color.accentColor.opacity(0.1) : Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium)
                    .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
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
}

#Preview {
    let workspace = Workspace(
        name: "MyProject",
        path: URL(fileURLWithPath: "/Users/dev/MyProject")
    )
    
    return WorkspaceAgentsView(
        workspace: workspace,
        onSelectAgent: { agent in print("Selected: \(agent.name)") },
        onStartNewWorktreeAgent: { print("Start new") }
    )
    .environment(AgentManager())
    .frame(width: 400, height: 500)
}
#endif
