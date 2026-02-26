#if os(macOS)
import SwiftUI
import ACPModel

/// Main container view for a single agent with chat and tool calls panels
public struct AgentView: View {
    let agent: Agent
    
    public init(agent: Agent) {
        self.agent = agent
    }
    
    public var body: some View {
        HSplitView {
            ChatPanel(agent: agent)
                .frame(minWidth: 300)
            
            CodePanel(agent: agent)
                .frame(minWidth: 200, idealWidth: 320, maxWidth: 500)
        }
        .navigationTitle(agent.name)
    }
}

/// Sidebar panel showing current and recent tool calls
struct ToolCallsPanel: View {
    let agent: Agent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tool Calls")
                .font(.headline)
                .padding()
            
            Divider()
            
            if agent.activeToolCalls.isEmpty {
                VStack {
                    Spacer()
                    Text("No active tool calls")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(agent.activeToolCalls, id: \.toolCallId) { toolCall in
                        ToolCallRow(toolCall: toolCall)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

/// Row displaying a single tool call with status and details
struct ToolCallRow: View {
    let toolCall: ToolCallUpdate
    
    private var statusIcon: String {
        switch toolCall.status {
        case .pending:
            return "clock"
        case .inProgress:
            return "arrow.triangle.2.circlepath"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .none:
            return "clock"
        }
    }
    
    private var statusColor: Color {
        switch toolCall.status {
        case .pending, .none:
            return .secondary
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    private var kindIcon: String {
        switch toolCall.kind {
        case .read:
            return "doc.text"
        case .edit:
            return "pencil"
        case .delete:
            return "trash"
        case .move:
            return "arrow.right.arrow.left"
        case .search:
            return "magnifyingglass"
        case .execute:
            return "terminal"
        case .think:
            return "brain"
        case .fetch:
            return "arrow.down.circle"
        case .switchMode, .other, .none:
            return "questionmark.circle"
        }
    }
    
    private var contentText: String? {
        for item in toolCall.content {
            if case .content(let c) = item, case .text(let t) = c.content {
                return t.text
            }
        }
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: kindIcon)
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                
                Text(toolCall.title)
                    .font(.subheadline)
                    .lineLimit(2)
                
                Spacer()
                
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
            }
            
            if let text = contentText, !text.isEmpty {
                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let workspace = Workspace(
        name: "Test Project",
        path: URL(fileURLWithPath: "/Users/test/Projects/test-project")
    )
    let agent = Agent(
        name: "Test Agent",
        workspace: workspace,
        status: .active,
        messages: [
            ChatMessage(role: .user, content: "Hello!"),
            ChatMessage(role: .assistant, content: "Hi there!")
        ],
        activeToolCalls: [
            ToolCallUpdate(
                toolCallId: "1",
                title: "Reading file.swift",
                kind: .read,
                status: .completed
            ),
            ToolCallUpdate(
                toolCallId: "2",
                title: "Editing main.swift",
                kind: .edit,
                status: .inProgress
            ),
            ToolCallUpdate(
                toolCallId: "3",
                title: "swift build",
                kind: .execute,
                status: .completed
            )
        ],
        fileChanges: [
            FileChange(
                path: "Sources/main.swift",
                oldContent: "let x = 1",
                newContent: "let x = 2\nlet y = 3",
                changeType: .modified,
                toolCallId: "2"
            )
        ]
    )
    
    AgentView(agent: agent)
        .frame(width: 900, height: 600)
}
#endif
