#if os(macOS)
import SwiftUI

/// Unified diff view showing file changes with hunk-based display
struct DiffView: View {
    let fileDiff: GitFileDiff

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // File header
            HStack {
                Image(systemName: changeTypeIcon)
                    .foregroundColor(changeTypeColor)
                Text(fileDiff.filePath)
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
                HStack(spacing: 8) {
                    if fileDiff.linesAdded > 0 {
                        Text("+\(fileDiff.linesAdded)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    if fileDiff.linesRemoved > 0 {
                        Text("-\(fileDiff.linesRemoved)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Diff content
            if fileDiff.isBinary {
                VStack {
                    Spacer()
                    Image(systemName: "doc.zipper")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Binary file changed")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if fileDiff.hunks.isEmpty {
                VStack {
                    Spacer()
                    Text("No diff content available")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(fileDiff.hunks.enumerated()), id: \.element.id) { index, hunk in
                            // Separator between hunks
                            if index > 0 {
                                HStack(spacing: 0) {
                                    Text("...")
                                        .frame(width: 40, alignment: .center)
                                        .foregroundColor(.secondary)
                                    Text("...")
                                        .frame(width: 40, alignment: .center)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .font(.system(size: 12, design: .monospaced))
                                .padding(.vertical, 2)
                                .background(Color(nsColor: .separatorColor).opacity(0.3))
                            }

                            // Hunk header
                            HStack(spacing: 0) {
                                Text(hunk.header)
                                    .foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                            .background(Color.blue.opacity(0.1))

                            // Hunk lines
                            ForEach(hunk.lines) { line in
                                DiffHunkLineView(line: line)
                            }
                        }
                    }
                }
            }
        }
        .font(.system(.body, design: .monospaced))
    }

    // MARK: - Helpers

    private var changeTypeIcon: String {
        switch fileDiff.changeType {
        case .created:
            return "plus.circle.fill"
        case .modified:
            return "pencil.circle.fill"
        case .deleted:
            return "minus.circle.fill"
        }
    }

    private var changeTypeColor: Color {
        switch fileDiff.changeType {
        case .created:
            return .green
        case .modified:
            return .yellow
        case .deleted:
            return .red
        }
    }
}

/// View for a single diff hunk line
struct DiffHunkLineView: View {
    let line: DiffHunkLine

    var body: some View {
        HStack(spacing: 0) {
            // Old line number
            Text(line.oldLineNumber.map { String($0) } ?? "")
                .frame(width: 40, alignment: .trailing)
                .padding(.horizontal, 4)
                .foregroundColor(.secondary)

            // New line number
            Text(line.newLineNumber.map { String($0) } ?? "")
                .frame(width: 40, alignment: .trailing)
                .padding(.horizontal, 4)
                .foregroundColor(.secondary)

            // Diff indicator
            Text(diffIndicator)
                .frame(width: 16)
                .foregroundColor(lineColor)

            // Line content
            Text(line.content.isEmpty ? " " : line.content)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.vertical, 1)
        .background(backgroundColor)
    }

    private var diffIndicator: String {
        switch line.type {
        case .context:
            return " "
        case .addition:
            return "+"
        case .deletion:
            return "-"
        }
    }

    private var lineColor: Color {
        switch line.type {
        case .context:
            return .primary
        case .addition:
            return .green
        case .deletion:
            return .red
        }
    }

    private var backgroundColor: Color {
        switch line.type {
        case .context:
            return .clear
        case .addition:
            return Color.green.opacity(0.15)
        case .deletion:
            return Color.red.opacity(0.15)
        }
    }
}

#Preview("Modified File") {
    let hunk = DiffHunk(
        oldStart: 1,
        oldCount: 5,
        newStart: 1,
        newCount: 6,
        header: "@@ -1,5 +1,6 @@",
        lines: [
            DiffHunkLine(type: .context, content: "import Foundation", oldLineNumber: 1, newLineNumber: 1),
            DiffHunkLine(type: .context, content: "", oldLineNumber: 2, newLineNumber: 2),
            DiffHunkLine(type: .deletion, content: "let x = 1", oldLineNumber: 3, newLineNumber: nil),
            DiffHunkLine(type: .addition, content: "let x = 2", oldLineNumber: nil, newLineNumber: 3),
            DiffHunkLine(type: .addition, content: "let y = 3", oldLineNumber: nil, newLineNumber: 4),
            DiffHunkLine(type: .context, content: "", oldLineNumber: 4, newLineNumber: 5),
            DiffHunkLine(type: .context, content: "func main() {", oldLineNumber: 5, newLineNumber: 6),
        ]
    )

    DiffView(fileDiff: GitFileDiff(
        filePath: "Sources/main.swift",
        changeType: .modified,
        hunks: [hunk],
        linesAdded: 2,
        linesRemoved: 1
    ))
    .frame(width: 600, height: 400)
}

#Preview("New File") {
    let hunk = DiffHunk(
        oldStart: 0,
        oldCount: 0,
        newStart: 1,
        newCount: 4,
        header: "@@ -0,0 +1,4 @@",
        lines: [
            DiffHunkLine(type: .addition, content: "import Foundation", oldLineNumber: nil, newLineNumber: 1),
            DiffHunkLine(type: .addition, content: "", oldLineNumber: nil, newLineNumber: 2),
            DiffHunkLine(type: .addition, content: "struct NewFile {", oldLineNumber: nil, newLineNumber: 3),
            DiffHunkLine(type: .addition, content: "    let value: Int", oldLineNumber: nil, newLineNumber: 4),
        ]
    )

    DiffView(fileDiff: GitFileDiff(
        filePath: "Sources/NewFile.swift",
        changeType: .created,
        hunks: [hunk],
        linesAdded: 4,
        linesRemoved: 0
    ))
    .frame(width: 600, height: 300)
}

#Preview("Binary File") {
    DiffView(fileDiff: GitFileDiff(
        filePath: "Resources/image.png",
        changeType: .modified,
        hunks: [],
        linesAdded: 0,
        linesRemoved: 0,
        isBinary: true
    ))
    .frame(width: 600, height: 200)
}
#endif
