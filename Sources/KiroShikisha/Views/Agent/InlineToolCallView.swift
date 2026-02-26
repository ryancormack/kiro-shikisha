#if os(macOS)
import SwiftUI
import ACPModel
import Foundation

/// Compact inline view of a tool call shown in the chat flow, expandable to show details
struct InlineToolCallView: View {
    let toolCall: ToolCallUpdate?
    let toolCallId: String
    @State private var isExpanded = false

    private var icon: String {
        switch toolCall?.kind {
        case .read: return "doc.text"
        case .edit: return "pencil"
        case .delete: return "trash"
        case .search: return "magnifyingglass"
        case .execute: return "terminal"
        case .think: return "brain"
        case .fetch: return "arrow.down.circle"
        default: return "wrench"
        }
    }

    private var statusColor: Color {
        switch toolCall?.status {
        case .completed: return .green
        case .inProgress: return .blue
        case .failed: return .red
        default: return .secondary
        }
    }

    private var statusIcon: String {
        switch toolCall?.status {
        case .completed: return "checkmark.circle.fill"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .failed: return "xmark.circle.fill"
        default: return "clock"
        }
    }

    private static let jsonEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private func formatJson(_ value: JsonValue) -> String {
        if let data = try? Self.jsonEncoder.encode(value),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "\(value)"
    }

    private var detailText: String? {
        guard let tc = toolCall else { return nil }
        var parts: [String] = []
        if let input = tc.rawInput { parts.append("Input:\n\(formatJson(input))") }
        if let output = tc.rawOutput { parts.append("Output:\n\(formatJson(output))") }
        if parts.isEmpty {
            for item in tc.content {
                if case .content(let c) = item, case .text(let t) = c.content {
                    parts.append(t.text)
                }
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 10)
                    Image(systemName: icon)
                        .foregroundColor(.secondary)
                        .frame(width: 14)
                    Text(toolCall?.title ?? "Tool call \(toolCallId.prefix(8))…")
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: statusIcon)
                        .font(.caption)
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if isExpanded, let detail = detailText {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(detail)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
#endif
