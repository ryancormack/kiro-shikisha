#if os(macOS)
import SwiftUI
import ACPModel
import Foundation

/// Compact inline view of a tool call shown in the chat flow, expandable to show details
struct InlineToolCallView: View {
    let toolCall: ToolCallUpdate?
    let toolCallId: String
    @State private var isExpanded = false
    @State private var isOutputExpanded = false
    @State private var isInputExpanded = false

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

    private var accentColor: Color {
        switch toolCall?.kind {
        case .execute: return .orange
        case .edit: return .blue
        case .delete: return .red
        case .search: return .purple
        case .read: return .cyan
        case .think: return .purple
        case .fetch: return .teal
        default: return .secondary
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

    /// Extract a short summary of the command/input for the header
    private var commandSummary: String? {
        guard let input = toolCall?.rawInput else { return nil }
        let json = formatJson(input)
        // Try to pull out a "command" field for execute-type calls
        if case .object(let dict) = input {
            if let cmd = dict["command"], case .string(let s) = cmd {
                return s
            }
            if let cmd = dict["input"], case .string(let s) = cmd {
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                return String(trimmed.prefix(120))
            }
        }
        // For short inputs, show inline
        if json.count < 80 {
            return json
        }
        return nil
    }

    @ViewBuilder
    private func collapsibleSection(
        label: String,
        icon: String,
        isExpanded: Binding<Bool>,
        lineCount: Int,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.wrappedValue.toggle() } }) {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Image(systemName: icon)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(label)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                    if lineCount > 0 {
                        Text("(\(lineCount) lines)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.vertical, 3)
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
            }
        }
    }

    @ViewBuilder
    private func codeBlock(_ text: String, maxHeight: CGFloat = 200) -> some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: true)
                .padding(8)
        }
        .frame(maxHeight: maxHeight)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusSmall))
    }

    @ViewBuilder
    private func toolCallContentView(_ item: ToolCallContent) -> some View {
        switch item {
        case .content(let c):
            if case .text(let t) = c.content {
                let text = t.text
                let lines = text.components(separatedBy: .newlines)
                let isLong = lines.count > 8
                VStack(alignment: .leading, spacing: 0) {
                    if isLong {
                        collapsibleSection(
                            label: "Output",
                            icon: "text.alignleft",
                            isExpanded: $isOutputExpanded,
                            lineCount: lines.count
                        ) {
                            codeBlock(text, maxHeight: 300)
                        }
                    } else {
                        codeBlock(text, maxHeight: 150)
                    }
                }
            }
        case .diff(let diff):
            VStack(alignment: .leading, spacing: 4) {
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
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.red)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(6)
                    .background(Color.red.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusSmall))
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    Text("+ " + diff.newText.prefix(500))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(6)
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
            // Header row
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 10)
                    Image(systemName: icon)
                        .foregroundColor(accentColor)
                        .frame(width: 14)
                    Text(toolCall?.title ?? "Tool call \(toolCallId.prefix(8))…")
                        .font(.system(.caption, weight: .medium))
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

            // Command summary shown below header when collapsed (for execute-type calls)
            if !isExpanded, let summary = commandSummary {
                Text(summary)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 6)
            }

            // Expanded detail
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Input section
                    if let input = toolCall?.rawInput {
                        let formatted = formatJson(input)
                        let lines = formatted.components(separatedBy: .newlines)
                        collapsibleSection(
                            label: "Input",
                            icon: "arrow.right.circle",
                            isExpanded: $isInputExpanded,
                            lineCount: lines.count
                        ) {
                            codeBlock(formatted)
                        }
                    }

                    // Output section
                    if let output = toolCall?.rawOutput {
                        let formatted = formatJson(output)
                        let lines = formatted.components(separatedBy: .newlines)
                        let isLong = lines.count > 10
                        if isLong {
                            collapsibleSection(
                                label: "Raw Output",
                                icon: "arrow.left.circle",
                                isExpanded: $isOutputExpanded,
                                lineCount: lines.count
                            ) {
                                codeBlock(formatted, maxHeight: 300)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.left.circle")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                    Text("Raw Output")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                codeBlock(formatted)
                            }
                        }
                    }

                    // Structured content (diffs, terminal refs, text output)
                    if let tc = toolCall, !tc.content.isEmpty {
                        ForEach(Array(tc.content.enumerated()), id: \.offset) { _, item in
                            toolCallContentView(item)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accentColor.opacity(0.4))
                .frame(width: 2)
        }
        .background(DesignConstants.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium))
    }
}
#endif
