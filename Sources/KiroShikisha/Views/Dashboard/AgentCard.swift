#if os(macOS)
import SwiftUI

/// Compact card showing an agent's current state in the dashboard
public struct AgentCard: View {
    let agent: Agent
    let onSelect: () -> Void
    
    @State private var isHovered: Bool = false
    
    public init(agent: Agent, onSelect: @escaping () -> Void) {
        self.agent = agent
        self.onSelect = onSelect
    }
    
    private var lastMessagePreview: String? {
        guard let lastMessage = agent.messages.last else { return nil }
        let text = lastMessage.content
        if text.count > 100 {
            return String(text.prefix(100)) + "..."
        }
        return text
    }
    
    private var activeToolCallName: String? {
        guard let activeCall = agent.activeToolCalls.first(where: { $0.status == .inProgress }) else {
            return nil
        }
        return activeCall.title
    }
    
    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Header: Agent name and status
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(agent.name)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(agent.workspace.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    AgentStatusIndicator(status: agent.status)
                }
                
                Divider()
                
                // Content: Last message or active tool
                VStack(alignment: .leading, spacing: 8) {
                    if let toolName = activeToolCallName {
                        // Show active tool call
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Text(toolName)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                        }
                    }
                    
                    if let preview = lastMessagePreview {
                        Text(preview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("No messages yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .frame(minHeight: 50, alignment: .top)
                
                // Error message if present
                if agent.status == .error, let errorMessage = agent.errorMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(
                        color: isHovered ? .black.opacity(0.15) : .black.opacity(0.05),
                        radius: isHovered ? 8 : 4,
                        y: isHovered ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    let workspace = Workspace(
        name: "Test Project",
        path: URL(fileURLWithPath: "/Users/test/Projects/test-project")
    )
    
    let activeAgent = Agent(
        name: "Active Agent",
        workspace: workspace,
        status: .active,
        messages: [
            ChatMessage(role: .user, content: "Please add a new feature"),
            ChatMessage(role: .assistant, content: "I'll help you add that feature. Let me start by reading the existing code...")
        ],
        activeToolCalls: [
            ToolCall(
                toolCallId: "1",
                title: "Reading main.swift",
                kind: .read,
                status: .inProgress
            )
        ]
    )
    
    let idleAgent = Agent(
        name: "Idle Agent",
        workspace: Workspace(name: "Another Project", path: URL(fileURLWithPath: "/Users/test/Projects/another")),
        status: .idle,
        messages: [
            ChatMessage(role: .assistant, content: "Task completed successfully!")
        ]
    )
    
    let errorAgent = Agent(
        name: "Error Agent",
        workspace: Workspace(name: "Broken Project", path: URL(fileURLWithPath: "/Users/test/Projects/broken")),
        status: .error,
        errorMessage: "Connection lost to kiro-cli process"
    )
    
    return VStack(spacing: 16) {
        AgentCard(agent: activeAgent) { print("Selected active") }
        AgentCard(agent: idleAgent) { print("Selected idle") }
        AgentCard(agent: errorAgent) { print("Selected error") }
    }
    .padding()
    .frame(width: 350)
}
#endif
