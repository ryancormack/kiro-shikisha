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
                                .frame(width: 110, alignment: .leading)
                            Text(entry.summary)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                        }
                        .id(entry.id)
                        .padding(.horizontal, DesignConstants.spacingSM)
                        .padding(.vertical, 1)
                    }
                }
                .padding(.vertical, DesignConstants.spacingXS)
            }
            .onChange(of: agent.debugLog.count) { _, _ in
                if let last = agent.debugLog.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func colorFor(_ type: String) -> Color {
        switch type {
        case "agent_message": return .green
        case "tool_call": return .orange
        case "tool_call_update": return .yellow
        case "thought": return .purple
        case "commands": return .cyan
        default: return .secondary
        }
    }
}
#endif
