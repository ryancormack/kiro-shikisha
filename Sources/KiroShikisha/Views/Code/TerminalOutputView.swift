#if os(macOS)
import SwiftUI
import ACPModel

/// Entry representing a single terminal command and its output
struct TerminalEntry: Identifiable {
    let id = UUID()
    let toolCallId: String
    let title: String
    let status: ToolCallStatus
    let output: String
}

/// View displaying terminal output from agent's execute tool calls
struct TerminalOutputView: View {
    let agent: Agent
    
    var body: some View {
        if terminalEntries.isEmpty {
            VStack {
                Spacer()
                Image(systemName: "terminal")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No terminal output yet")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text("Commands executed by the agent will appear here")
                    .foregroundColor(.secondary)
                    .font(.caption2)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(terminalEntries) { entry in
                        TerminalEntryView(entry: entry)
                    }
                }
                .padding()
            }
        }
    }
    
    /// Extract terminal entries from execute tool calls
    private var terminalEntries: [TerminalEntry] {
        agent.toolCallHistory.values
            .filter { $0.kind == .execute }
            .sorted { ($0.toolCallId.value) < ($1.toolCallId.value) }
            .map { toolCall in
                TerminalEntry(
                    toolCallId: toolCall.toolCallId.value,
                    title: toolCall.title,
                    status: toolCall.status ?? .pending,
                    output: stripAnsiCodes(extractText(from: toolCall.content))
                )
            }
    }
    
    /// Extract text content from ToolCallContent array
    private func extractText(from content: [ToolCallContent]) -> String {
        content.compactMap { item in
            if case .content(let c) = item, case .text(let t) = c.content {
                return t.text
            }
            return nil
        }.joined(separator: "\n")
    }
    
    /// Strip ANSI escape codes from terminal output
    private func stripAnsiCodes(_ text: String) -> String {
        // Match ANSI escape sequences: ESC [ ... m and other control sequences
        // Pattern: \x1B (or \e) followed by [ then parameters and command letter
        guard let regex = try? NSRegularExpression(
            pattern: "\\x1B\\[[0-9;]*[A-Za-z]|\\x1B\\].*?\\x07",
            options: []
        ) else {
            return text
        }
        
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }
}

/// View for a single terminal entry showing command and output
struct TerminalEntryView: View {
    let entry: TerminalEntry
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with command title and status
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    
                    Image(systemName: "terminal")
                        .foregroundColor(.secondary)
                    
                    Text(entry.title)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    StatusIndicator(status: entry.status)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                // Terminal output
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(entry.output.isEmpty ? "(no output)" : entry.output)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(entry.output.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}

/// Status indicator for terminal command
struct StatusIndicator: View {
    let status: ToolCallStatus
    
    var body: some View {
        HStack(spacing: 4) {
            if status == .inProgress {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
            }
            
            Text(statusText)
                .font(.caption2)
                .foregroundColor(statusColor)
        }
    }
    
    private var statusIcon: String {
        switch status {
        case .pending:
            return "clock"
        case .inProgress:
            return "arrow.triangle.2.circlepath"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .pending:
            return .secondary
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    private var statusText: String {
        switch status {
        case .pending:
            return "Pending"
        case .inProgress:
            return "Running"
        case .completed:
            return "Done"
        case .failed:
            return "Failed"
        }
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
        activeToolCalls: [
            ToolCallUpdate(
                toolCallId: "exec-1",
                title: "swift build",
                kind: .execute,
                status: .completed
            ),
            ToolCallUpdate(
                toolCallId: "exec-2",
                title: "swift test",
                kind: .execute,
                status: .inProgress
            ),
            ToolCallUpdate(
                toolCallId: "exec-3",
                title: "git status",
                kind: .execute,
                status: .failed
            ),
            ToolCallUpdate(
                toolCallId: "read-1",
                title: "Reading Package.swift",
                kind: .read,
                status: .completed
            )
        ]
    )
    
    TerminalOutputView(agent: agent)
        .frame(width: 500, height: 400)
}

#Preview("Empty State") {
    let workspace = Workspace(
        name: "Test Project",
        path: URL(fileURLWithPath: "/Users/test/Projects/test-project")
    )
    let agent = Agent(
        name: "Test Agent",
        workspace: workspace
    )
    
    TerminalOutputView(agent: agent)
        .frame(width: 400, height: 300)
}
#endif
