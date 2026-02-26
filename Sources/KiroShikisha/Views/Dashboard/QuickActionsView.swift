#if os(macOS)
import SwiftUI

/// Floating panel with bulk actions for managing all agents
public struct QuickActionsView: View {
    @Environment(AgentManager.self) var agentManager
    
    /// Callback when stop all is triggered
    let onStopAll: () async -> Void
    /// Callback when refresh all is triggered
    let onRefreshAll: () async -> Void
    /// Callback when new worktree agent is requested
    let onNewWorktreeAgent: (() -> Void)?
    
    @State private var isStoppingAll: Bool = false
    @State private var isRefreshingAll: Bool = false
    
    public init(
        onStopAll: @escaping () async -> Void,
        onRefreshAll: @escaping () async -> Void,
        onNewWorktreeAgent: (() -> Void)? = nil
    ) {
        self.onStopAll = onStopAll
        self.onRefreshAll = onRefreshAll
        self.onNewWorktreeAgent = onNewWorktreeAgent
    }
    
    private var activeAgentCount: Int {
        agentManager.getAllAgents().count
    }
    
    private var hasActiveAgents: Bool {
        activeAgentCount > 0
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            // Agent count display
            agentCountDisplay
            
            Divider()
                .frame(height: 24)
            
            // New Worktree Agent button
            if let onNewWorktreeAgent = onNewWorktreeAgent {
                newWorktreeAgentButton(action: onNewWorktreeAgent)
            }
            
            // Stop All Agents button
            stopAllButton
            
            // Refresh All button
            refreshAllButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(backgroundView)
    }
    
    private var agentCountDisplay: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text("\(activeAgentCount)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("agent\(activeAgentCount == 1 ? "" : "s")")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    private func newWorktreeAgentButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 12))
                Text("New Worktree Agent")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
        .help("Start a new agent in a git worktree (⇧⌘N)")
        .keyboardShortcut("n", modifiers: [.command, .shift])
    }
    
    private var stopAllButton: some View {
        Button {
            Task {
                isStoppingAll = true
                await onStopAll()
                isStoppingAll = false
            }
        } label: {
            HStack(spacing: 4) {
                if isStoppingAll {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 12))
                }
                Text("Stop All")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(hasActiveAgents ? .red : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(!hasActiveAgents || isStoppingAll)
        .help("Stop all active agents")
    }
    
    private var refreshAllButton: some View {
        Button {
            Task {
                isRefreshingAll = true
                await onRefreshAll()
                isRefreshingAll = false
            }
        } label: {
            HStack(spacing: 4) {
                if isRefreshingAll {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                Text("Refresh All")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
        .disabled(isRefreshingAll)
        .help("Reconnect all agents")
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(nsColor: .controlBackgroundColor))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    QuickActionsView(
        onStopAll: { 
            try? await Task.sleep(for: .seconds(1))
        },
        onRefreshAll: {
            try? await Task.sleep(for: .seconds(1))
        },
        onNewWorktreeAgent: {
            print("New worktree agent requested")
        }
    )
    .environment(AgentManager())
    .padding()
    .frame(width: 500)
}
#endif
