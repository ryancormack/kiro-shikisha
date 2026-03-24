#if os(macOS)
// DEPRECATED: This view is being replaced by TaskRow as part of the task-centric architecture refactor.
// Kept for backward compatibility with workspace settings views.
import SwiftUI
public struct WorkspaceRow: View {
    @Environment(AgentManager.self) var agentManager
    
    let workspace: Workspace
    let agent: Agent?
    
    /// Number of resumable sessions for this workspace (optional)
    var sessionCount: Int?
    
    /// Callback when session history button is tapped
    var onShowSessionHistory: (() -> Void)?
    
    public init(
        workspace: Workspace,
        agent: Agent? = nil,
        sessionCount: Int? = nil,
        onShowSessionHistory: (() -> Void)? = nil
    ) {
        self.workspace = workspace
        self.agent = agent
        self.sessionCount = sessionCount
        self.onShowSessionHistory = onShowSessionHistory
    }
    
    private var truncatedPath: String {
        let path = workspace.path.path
        if path.count > 40 {
            let start = path.prefix(15)
            let end = path.suffix(22)
            return "\(start)...\(end)"
        }
        return path
    }
    
    /// Whether this workspace is a worktree child (created from another workspace)
    private var isWorktreeChild: Bool {
        workspace.sourceWorkspaceId != nil || workspace.gitWorktreePath != nil
    }
    
    /// Count of active agents in this workspace and its worktrees
    private var activeAgentCount: Int {
        agentManager.getAgentsForWorkspace(workspace.id).count
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Icon with worktree indicator
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                if isWorktreeChild {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.purple)
                        .padding(2)
                        .background(Color(.controlBackgroundColor))
                        .clipShape(Circle())
                        .offset(x: 4, y: 4)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(workspace.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    // Show branch badge for worktrees
                    if isWorktreeChild, let branch = workspace.gitBranch {
                        Text(branch)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.badgeCornerRadius))
                    }
                }
                
                Text(truncatedPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Active agent count badge (for workspaces with worktree agents)
            if activeAgentCount > 0 && agent == nil {
                activeAgentsBadge
            }
            
            // Session count badge
            if let count = sessionCount, count > 0, agent == nil, activeAgentCount == 0 {
                Button(action: { onShowSessionHistory?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                        Text("\(count)")
                            .font(.caption)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: DesignConstants.badgeCornerRadius))
                }
                .buttonStyle(.plain)
                .help("View \(count) previous session\(count == 1 ? "" : "s")")
            }
            
            if let agent = agent {
                StatusBadge(status: agent.status)
            }
        }
        .padding(.vertical, 4)
        // Indent worktree children slightly
        .padding(.leading, isWorktreeChild ? 8 : 0)
    }
    
    /// Badge showing count of active agents in this workspace tree
    private var activeAgentsBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "person.fill")
                .font(.system(size: 9))
            Text("\(activeAgentCount)")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.blue)
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium))
        .help("\(activeAgentCount) active agent\(activeAgentCount == 1 ? "" : "s") in workspace")
    }
}

#Preview {
    let regularWorkspace = Workspace(
        name: "MyProject",
        path: URL(fileURLWithPath: "/Users/developer/Projects/MyProject")
    )
    
    let worktreeWorkspace = Workspace(
        name: "MyProject-feature",
        path: URL(fileURLWithPath: "/Users/developer/Projects/MyProject-feature"),
        gitBranch: "feature/new-ui",
        gitWorktreePath: URL(fileURLWithPath: "/Users/developer/Projects/MyProject-feature"),
        sourceWorkspaceId: UUID()
    )
    
    let agent = Agent(name: "Test Agent", workspace: regularWorkspace, status: .active)
    
    return VStack(alignment: .leading, spacing: 8) {
        Text("Regular workspace with agent:").font(.caption).foregroundColor(.secondary)
        WorkspaceRow(workspace: regularWorkspace, agent: agent)
        
        Divider()
        
        Text("Workspace with sessions:").font(.caption).foregroundColor(.secondary)
        WorkspaceRow(
            workspace: regularWorkspace,
            agent: nil,
            sessionCount: 3,
            onShowSessionHistory: { print("Show history") }
        )
        
        Divider()
        
        Text("Worktree workspace:").font(.caption).foregroundColor(.secondary)
        WorkspaceRow(workspace: worktreeWorkspace, agent: nil)
    }
    .padding()
    .frame(width: 350)
    .environment(AgentManager())
}
#endif
