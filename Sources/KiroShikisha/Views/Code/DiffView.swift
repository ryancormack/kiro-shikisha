#if os(macOS)
import SwiftUI

/// Polished unified diff view with line numbers, colored borders, word-level highlighting,
/// and bidirectional scrolling for long lines.
struct DiffView: View {
    let fileDiff: GitFileDiff

    @State private var collapsedHunks: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sticky file header
            fileHeader

            Divider()

            // Diff content
            if fileDiff.isBinary {
                binaryFileState
            } else if fileDiff.hunks.isEmpty {
                emptyDiffState
            } else {
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(fileDiff.hunks.enumerated()), id: \.element.id) { index, hunk in
                            // Hunk header bar
                            hunkHeaderView(hunk: hunk)

                            // Hunk lines (collapsible)
                            if !collapsedHunks.contains(hunk.id) {
                                let wordDiffMap = computeWordDiffs(for: hunk)
                                ForEach(Array(hunk.lines.enumerated()), id: \.element.id) { lineIndex, line in
                                    DiffHunkLineView(
                                        line: line,
                                        wordHighlight: wordDiffMap[line.id]
                                    )
                                }
                            }
                        }
                    }
                    .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - File Header

    private var fileHeader: some View {
        HStack(spacing: DesignConstants.spacingSM) {
            Image(systemName: changeTypeIcon)
                .foregroundColor(changeTypeColor)
                .font(.system(size: 14, weight: .semibold))

            VStack(alignment: .leading, spacing: 2) {
                Text(fileDiff.fileName)
                    .font(.headline)
                    .fontWeight(.medium)
                if !fileDiff.directoryPath.isEmpty {
                    Text(fileDiff.directoryPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: DesignConstants.spacingSM) {
                if fileDiff.linesAdded > 0 {
                    Text("+\(fileDiff.linesAdded)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                if fileDiff.linesRemoved > 0 {
                    Text("-\(fileDiff.linesRemoved)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.horizontal, DesignConstants.spacingLG)
        .padding(.vertical, DesignConstants.spacingMD)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Hunk Header

    private func hunkHeaderView(hunk: DiffHunk) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                if collapsedHunks.contains(hunk.id) {
                    collapsedHunks.remove(hunk.id)
                } else {
                    collapsedHunks.insert(hunk.id)
                }
            }
        }) {
            HStack(spacing: DesignConstants.spacingSM) {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(collapsedHunks.contains(hunk.id) ? 0 : 90))
                    .foregroundColor(.blue.opacity(0.7))
                    .frame(width: 12)

                Text(hunk.header)
                    .font(.system(size: DesignConstants.codeFontSize, design: .monospaced))
                    .foregroundColor(.blue.opacity(0.8))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DesignConstants.spacingSM)
            .padding(.vertical, DesignConstants.spacingXS)
            .background(Color.blue.opacity(0.06))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Binary / Empty States

    private var binaryFileState: some View {
        VStack(spacing: DesignConstants.spacingSM) {
            Spacer()
            Image(systemName: "doc.zipper")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("Binary file")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Cannot display diff for binary content")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyDiffState: some View {
        VStack(spacing: DesignConstants.spacingSM) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No changes")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Word-Level Diff Computation

    /// For each line in a hunk, compute word-level highlighting when a deletion is
    /// immediately followed by one or more additions.
    private func computeWordDiffs(for hunk: DiffHunk) -> [UUID: WordHighlight] {
        var result: [UUID: WordHighlight] = [:]
        let lines = hunk.lines
        var i = 0

        while i < lines.count {
            // Find a run of deletions followed by a run of additions
            if lines[i].type == .deletion {
                var deletionStart = i
                while i < lines.count && lines[i].type == .deletion {
                    i += 1
                }
                let deletionEnd = i

                var additionStart = i
                while i < lines.count && lines[i].type == .addition {
                    i += 1
                }
                let additionEnd = i

                let deletionCount = deletionEnd - deletionStart
                let additionCount = additionEnd - additionStart

                if additionCount > 0 {
                    // Pair up deletions and additions for word-level diff
                    let pairCount = min(deletionCount, additionCount)
                    for p in 0..<pairCount {
                        let delLine = lines[deletionStart + p]
                        let addLine = lines[additionStart + p]
                        let (delHighlight, addHighlight) = wordDiff(
                            oldText: delLine.content,
                            newText: addLine.content
                        )
                        result[delLine.id] = delHighlight
                        result[addLine.id] = addHighlight
                    }
                }
            } else {
                i += 1
            }
        }

        return result
    }

    /// Compute word-level diff between old and new text by finding common prefix and suffix
    /// at the word boundary level.
    private func wordDiff(oldText: String, newText: String) -> (WordHighlight, WordHighlight) {
        let oldWords = oldText.components(separatedBy: " ")
        let newWords = newText.components(separatedBy: " ")

        // Find common prefix length
        var prefixLen = 0
        while prefixLen < oldWords.count && prefixLen < newWords.count
                && oldWords[prefixLen] == newWords[prefixLen] {
            prefixLen += 1
        }

        // Find common suffix length (not overlapping with prefix)
        var suffixLen = 0
        while suffixLen < (oldWords.count - prefixLen)
                && suffixLen < (newWords.count - prefixLen)
                && oldWords[oldWords.count - 1 - suffixLen] == newWords[newWords.count - 1 - suffixLen] {
            suffixLen += 1
        }

        // Calculate character ranges for the changed middle portion
        let oldPrefixChars = prefixLen > 0
            ? oldWords[0..<prefixLen].joined(separator: " ").count + 1
            : 0
        let oldSuffixChars = suffixLen > 0
            ? oldWords[(oldWords.count - suffixLen)...].joined(separator: " ").count + 1
            : 0
        let newPrefixChars = prefixLen > 0
            ? newWords[0..<prefixLen].joined(separator: " ").count + 1
            : 0
        let newSuffixChars = suffixLen > 0
            ? newWords[(newWords.count - suffixLen)...].joined(separator: " ").count + 1
            : 0

        let oldHighlightStart = oldPrefixChars
        let oldHighlightEnd = max(oldHighlightStart, oldText.count - oldSuffixChars)
        let newHighlightStart = newPrefixChars
        let newHighlightEnd = max(newHighlightStart, newText.count - newSuffixChars)

        return (
            WordHighlight(start: oldHighlightStart, end: oldHighlightEnd, isDeletion: true),
            WordHighlight(start: newHighlightStart, end: newHighlightEnd, isDeletion: false)
        )
    }
}

/// Describes which character range in a line should get stronger highlight
struct WordHighlight {
    let start: Int
    let end: Int
    let isDeletion: Bool
}

/// View for a single diff hunk line with optional word-level highlighting
struct DiffHunkLineView: View {
    let line: DiffHunkLine
    let wordHighlight: WordHighlight?

    init(line: DiffHunkLine, wordHighlight: WordHighlight? = nil) {
        self.line = line
        self.wordHighlight = wordHighlight
    }

    var body: some View {
        HStack(spacing: 0) {
            // Change indicator strip (colored left border)
            Rectangle()
                .fill(indicatorColor)
                .frame(width: DesignConstants.changeIndicatorWidth)

            // Old line number
            Text(line.oldLineNumber.map { String($0) } ?? "")
                .frame(width: DesignConstants.lineNumberGutterWidth, alignment: .trailing)
                .padding(.trailing, DesignConstants.spacingXS)
                .font(.system(size: DesignConstants.codeLineNumberFontSize, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(.secondary.opacity(0.6))

            // Subtle vertical divider
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.3))
                .frame(width: 1)

            // New line number
            Text(line.newLineNumber.map { String($0) } ?? "")
                .frame(width: DesignConstants.lineNumberGutterWidth, alignment: .trailing)
                .padding(.trailing, DesignConstants.spacingXS)
                .font(.system(size: DesignConstants.codeLineNumberFontSize, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(.secondary.opacity(0.6))

            // Subtle vertical divider
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.3))
                .frame(width: 1)

            // Line content
            lineContent
                .padding(.leading, DesignConstants.spacingSM)
        }
        .font(.system(size: DesignConstants.codeFontSize, design: .monospaced))
        .padding(.vertical, 1)
        .background(backgroundColor)
    }

    @ViewBuilder
    private var lineContent: some View {
        if let highlight = wordHighlight, highlight.start < highlight.end {
            highlightedText(content: line.content, highlight: highlight)
        } else {
            Text(line.content.isEmpty ? " " : line.content)
        }
    }

    private func highlightedText(content: String, highlight: WordHighlight) -> some View {
        let text = content.isEmpty ? " " : content
        let startIdx = text.index(text.startIndex, offsetBy: min(highlight.start, text.count))
        let endIdx = text.index(text.startIndex, offsetBy: min(highlight.end, text.count))

        let prefix = String(text[text.startIndex..<startIdx])
        let middle = String(text[startIdx..<endIdx])
        let suffix = String(text[endIdx..<text.endIndex])

        let highlightColor = highlight.isDeletion
            ? Color.red.opacity(0.25)
            : Color.green.opacity(0.25)

        return HStack(spacing: 0) {
            if !prefix.isEmpty {
                Text(prefix)
            }
            Text(middle)
                .background(highlightColor)
            if !suffix.isEmpty {
                Text(suffix)
            }
        }
    }

    private var indicatorColor: Color {
        switch line.type {
        case .context:
            return .clear
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
            return Color.green.opacity(0.08)
        case .deletion:
            return Color.red.opacity(0.08)
        }
    }
}

// MARK: - Previews

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
    .frame(width: 1000, height: 650)
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
    .frame(width: 1000, height: 650)
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
    .frame(width: 1000, height: 400)
}
#endif
