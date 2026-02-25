#if os(macOS)
import SwiftUI

/// Dashboard view showing all active agents in a grid layout
public struct DashboardView: View {
    @Environment(AgentManager.self) var agentManager
    
    let onSelectAgent: (Agent) -> Void
    
    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 450), spacing: 16)
    ]
    
    public init(onSelectAgent: @escaping (Agent) -> Void) {
        self.onSelectAgent = onSelectAgent
    }
    
    private var activeAgents: [Agent] {
        agentManager.getAllAgents()
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Active Agents")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(activeAgents.count) agent\(activeAgents.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            // Content
            if activeAgents.isEmpty {
                emptyStateView
            } else {
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
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    DashboardView { agent in
        print("Selected agent: \(agent.name)")
    }
    .environment(AgentManager())
    .frame(width: 800, height: 600)
}
#endif
