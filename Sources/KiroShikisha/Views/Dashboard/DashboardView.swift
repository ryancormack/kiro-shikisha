#if os(macOS)
import SwiftUI

/// Dashboard view showing all active agents in a grid layout
public struct DashboardView: View {
    @Environment(AgentManager.self) var agentManager
    
    let onSelectAgent: (Agent) -> Void
    var onNewWorktreeAgent: (() -> Void)?
    
    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 450), spacing: 16)
    ]
    
    public init(
        onSelectAgent: @escaping (Agent) -> Void,
        onNewWorktreeAgent: (() -> Void)? = nil
    ) {
        self.onSelectAgent = onSelectAgent
        self.onNewWorktreeAgent = onNewWorktreeAgent
    }
    
    private var activeAgents: [Agent] {
        agentManager.getAllAgents()
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header with Quick Actions
            HStack {
                Text("Active Agents")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                QuickActionsView(
                    onStopAll: stopAllAgents,
                    onRefreshAll: refreshAllAgents,
                    onNewWorktreeAgent: onNewWorktreeAgent
                )
            }
            .padding()
            
            Divider()
            
            // Content
            if activeAgents.isEmpty {
                emptyStateView
            } else {
                HSplitView {
                    // Agent cards grid
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(activeAgents, id: \.id) { agent in
                                AgentCard(agent: agent) {
                                    onSelectAgent(agent)
                                }
                            }
                        }
                        .padding()
                    }
                    .frame(minWidth: 400)
                    
                    // Activity feed
                    ActivityFeed(events: agentManager.activityEvents)
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Active Agents")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Start a new agent from the sidebar to begin")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            // Add button for new worktree agent in empty state
            if let onNewWorktreeAgent = onNewWorktreeAgent {
                Button(action: onNewWorktreeAgent) {
                    Label("New Worktree Agent", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Stops all active agents
    private func stopAllAgents() async {
        let agentIds = activeAgents.map { $0.id }
        for id in agentIds {
            await agentManager.stopAgent(id: id)
        }
    }
    
    /// Refreshes all agents (reconnects them)
    private func refreshAllAgents() async {
        // For now, this is a placeholder that would reconnect agents
        // In a real implementation, this would disconnect and reconnect each agent
        // For now, we just simulate a delay
        try? await Task.sleep(for: .milliseconds(500))
    }
}

#Preview {
    DashboardView(
        onSelectAgent: { agent in
            print("Selected agent: \(agent.name)")
        },
        onNewWorktreeAgent: {
            print("New worktree agent requested")
        }
    )
    .environment(AgentManager())
    .frame(width: 800, height: 600)
}
#endif
