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
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.name)
                    .font(.headline)
                    .lineLimit(1)
                
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
    }
}

#Preview {
    let workspace = Workspace(
        name: "MyProject",
        path: URL(fileURLWithPath: "/Users/developer/Projects/MyProject")
    )
    let agent = Agent(name: "Test Agent", workspace: workspace, status: .active)
    
    return VStack {
        WorkspaceRow(workspace: workspace, agent: agent)
        WorkspaceRow(workspace: workspace, agent: nil)
    }
    .padding()
}
#endif
