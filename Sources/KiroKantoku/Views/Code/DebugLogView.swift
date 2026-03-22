#if os(macOS)
import SwiftUI

/// Shows raw ACP session update log for debugging
struct DebugLogView: View {
    let agent: Agent

    private var formatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .medium
        return f
    }

    var body: some View {
        ScrollViewReader { proxy in
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(agent.debugLog) { entry in
                            HStack(alignment: .top, spacing: DesignConstants.spacingSM) {
                                Text(formatter.string(from: entry.timestamp))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 70, alignment: .leading)
                                Text(entry.type)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(colorFor(entry.type))
                                    .frame(width: 160, alignment: .leading)
                                Text(entry.summary)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            .frame(minWidth: geometry.size.width, alignment: .leading)
                            .id(entry.id)
                            .padding(.horizontal, DesignConstants.spacingSM)
                            .padding(.vertical, 1)
                        }
                    }
                    .padding(.vertical, DesignConstants.spacingXS)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
                .onChange(of: agent.debugLog.count) { _, _ in
                    if let last = agent.debugLog.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func colorFor(_ type: String) -> Color {
        switch type {
        case "agent_message": return .green
        case "tool_call": return .orange
        case "tool_call_update": return .yellow
        case "thought": return .purple
        case "commands": return .cyan
        case "kiro_metadata": return .blue
        case "kiro_agent_switched": return .mint
        case "kiro_compaction": return .indigo
        case "kiro_clear": return .pink
        case "kiro_oauth": return .teal
        case "kiro_tool_chunk": return .brown
        case "kiro_commands_available": return .cyan
        case "kiro_session_update": return .blue
        case "permission_request": return .orange
        case "permission_response": return .green
        default: return .secondary
        }
    }
}
#endif
