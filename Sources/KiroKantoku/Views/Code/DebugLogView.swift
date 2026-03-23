#if os(macOS)
import AppKit
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
                            DebugLogEntryRow(
                                entry: entry,
                                formatter: formatter,
                                minWidth: geometry.size.width
                            )
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
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - DebugLogEntryRow

private struct DebugLogEntryRow: View {
    let entry: DebugLogEntry
    let formatter: DateFormatter
    let minWidth: CGFloat

    @State private var isExpanded = false

    private var hasRawJson: Bool {
        entry.rawJson != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed header row
            HStack(alignment: .top, spacing: DesignConstants.spacingSM) {
                if hasRawJson {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 10)
                        .padding(.top, 2)
                }

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
            .frame(minWidth: minWidth, alignment: .leading)
            .padding(.horizontal, DesignConstants.spacingSM)
            .padding(.vertical, 1)
            .contentShape(Rectangle())
            .onTapGesture {
                if hasRawJson {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                }
            }

            // Expanded raw JSON section
            if isExpanded, let rawJson = entry.rawJson {
                VStack(alignment: .leading, spacing: DesignConstants.spacingXS) {
                    HStack {
                        Text("Raw JSON")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(rawJson, forType: .string)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy")
                            }
                            .font(.system(.caption2))
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(rawJson)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .frame(maxHeight: 200)
                }
                .padding(DesignConstants.spacingSM)
                .background(DesignConstants.controlBackground.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusSmall))
                .padding(.horizontal, DesignConstants.spacingSM)
                .padding(.bottom, DesignConstants.spacingXS)
            }
        }
        .id(entry.id)
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
