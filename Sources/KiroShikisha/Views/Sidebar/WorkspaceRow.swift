#if os(macOS)
import SwiftUI

/// A row displaying workspace information with optional agent status
public struct WorkspaceRow: View {
    let workspace: Workspace
    let agent: Agent?
    
    public init(workspace: Workspace, agent: Agent? = nil) {
        self.workspace = workspace
        self.agent = agent
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
                            .cornerRadius(3)
                    }
                }
                
                Text(truncatedPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let agent = agent {
                StatusBadge(status: agent.status)
            }
        }
        .padding(.vertical, 4)
        // Indent worktree children slightly
        .padding(.leading, isWorktreeChild ? 8 : 0)
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
        Text("Regular workspace:").font(.caption).foregroundColor(.secondary)
        WorkspaceRow(workspace: regularWorkspace, agent: agent)
        
        Divider()
        
        Text("Regular workspace without agent:").font(.caption).foregroundColor(.secondary)
        WorkspaceRow(workspace: regularWorkspace, agent: nil)
        
        Divider()
        
        Text("Worktree workspace:").font(.caption).foregroundColor(.secondary)
        WorkspaceRow(workspace: worktreeWorkspace, agent: nil)
    }
    .padding()
    .frame(width: 300)
}
#endif
