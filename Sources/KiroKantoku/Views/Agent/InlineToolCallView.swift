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

    private func locationLabel(_ loc: ToolCallLocation) -> String {
        let fileName = (loc.path as NSString).lastPathComponent
        if let line = loc.line {
            return "\(fileName):\(line)"
        }
        return fileName
    }

    @ViewBuilder
    private func toolCallContentView(_ item: ToolCallContent) -> some View {
        switch item {
        case .content(let c):
            if case .text(let t) = c.content {
                Text(t.text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        case .diff(let diff):
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(diff.path)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                if let oldText = diff.oldText, !oldText.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text("- " + oldText.prefix(500))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.red)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(4)
                    .background(Color.red.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusSmall))
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    Text("+ " + diff.newText.prefix(500))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(4)
                .background(Color.green.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusSmall))
            }
        case .terminal(let term):
            HStack(spacing: 4) {
                Image(systemName: "terminal")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Terminal: \(term.terminalId)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
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
                    if let locations = toolCall?.locations, !locations.isEmpty {
                        ForEach(Array(locations.prefix(3).enumerated()), id: \.offset) { _, loc in
                            HStack(spacing: 2) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 8))
                                Text(locationLabel(loc))
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.badgeCornerRadius))
                        }
                    }
                    Spacer()
                    Image(systemName: statusIcon)
                        .font(.caption)
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    if let input = toolCall?.rawInput {
                        Text("Input:")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(formatJson(input))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .frame(maxHeight: 100)
                    }

                    if let output = toolCall?.rawOutput {
                        Text("Output:")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(formatJson(output))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .frame(maxHeight: 100)
                    }

                    if let tc = toolCall {
                        ForEach(Array(tc.content.enumerated()), id: \.offset) { _, item in
                            toolCallContentView(item)
                        }
                    }
                }
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusSmall))
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
        .background(DesignConstants.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium))
    }
}
#endif
