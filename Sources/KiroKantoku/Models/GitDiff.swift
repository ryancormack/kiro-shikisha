import Foundation

/// Represents a single file's diff from git
public struct GitFileDiff: Identifiable, Sendable {
    public let id: UUID
    public let filePath: String
    public let changeType: FileChangeType
    public let hunks: [DiffHunk]
    public let linesAdded: Int
    public let linesRemoved: Int
    public let isBinary: Bool

    public var fileName: String { (filePath as NSString).lastPathComponent }
    public var directoryPath: String { (filePath as NSString).deletingLastPathComponent }

    public init(
        id: UUID = UUID(),
        filePath: String,
        changeType: FileChangeType,
        hunks: [DiffHunk] = [],
        linesAdded: Int = 0,
        linesRemoved: Int = 0,
        isBinary: Bool = false
    ) {
        self.id = id
        self.filePath = filePath
        self.changeType = changeType
        self.hunks = hunks
        self.linesAdded = linesAdded
        self.linesRemoved = linesRemoved
        self.isBinary = isBinary
    }
}

/// A single hunk from a unified diff
public struct DiffHunk: Identifiable, Sendable {
    public let id: UUID
    public let oldStart: Int
    public let oldCount: Int
    public let newStart: Int
    public let newCount: Int
    public let header: String
    public let lines: [DiffHunkLine]

    public init(
        id: UUID = UUID(),
        oldStart: Int,
        oldCount: Int,
        newStart: Int,
        newCount: Int,
        header: String,
        lines: [DiffHunkLine] = []
    ) {
        self.id = id
        self.oldStart = oldStart
        self.oldCount = oldCount
        self.newStart = newStart
        self.newCount = newCount
        self.header = header
        self.lines = lines
    }
}

/// A single line within a diff hunk
public struct DiffHunkLine: Identifiable, Sendable {
    public let id: UUID
    public let type: DiffHunkLineType
    public let content: String
    public let oldLineNumber: Int?
    public let newLineNumber: Int?

    public init(
        id: UUID = UUID(),
        type: DiffHunkLineType,
        content: String,
        oldLineNumber: Int? = nil,
        newLineNumber: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
    }
}

/// Type of a diff hunk line
public enum DiffHunkLineType: Sendable {
    case context
    case addition
    case deletion
}

/// Parser for unified diff output from git
public enum GitDiffParser {
    /// Parse full `git diff` output into per-file diffs
    public static func parse(_ rawDiff: String) -> [GitFileDiff] {
        guard !rawDiff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let lines = rawDiff.components(separatedBy: "\n")
        var fileDiffs: [GitFileDiff] = []
        var currentFileStart: Int? = nil

        for (index, line) in lines.enumerated() {
            if line.hasPrefix("diff --git ") {
                // Save the previous file section
                if let start = currentFileStart {
                    if let diff = parseFileDiff(Array(lines[start..<index])) {
                        fileDiffs.append(diff)
                    }
                }
                currentFileStart = index
            }
        }

        // Parse the last file section
        if let start = currentFileStart {
            if let diff = parseFileDiff(Array(lines[start..<lines.count])) {
                fileDiffs.append(diff)
            }
        }

        return fileDiffs
    }

    /// Parse a single file diff section
    public static func parseFileDiff(_ lines: [String]) -> GitFileDiff? {
        guard !lines.isEmpty, lines[0].hasPrefix("diff --git ") else {
            return nil
        }

        // Extract file path from diff --git a/path b/path
        var filePath = ""
        var oldPath: String? = nil
        var newPath: String? = nil
        var changeType: FileChangeType = .modified
        var isBinary = false
        var hunkStartIndices: [Int] = []

        for (index, line) in lines.enumerated() {
            if line.hasPrefix("--- ") {
                let path = String(line.dropFirst(4))
                if path == "/dev/null" {
                    oldPath = nil
                } else {
                    // Strip a/ prefix
                    oldPath = path.hasPrefix("a/") ? String(path.dropFirst(2)) : path
                }
            } else if line.hasPrefix("+++ ") {
                let path = String(line.dropFirst(4))
                if path == "/dev/null" {
                    newPath = nil
                } else {
                    // Strip b/ prefix
                    newPath = path.hasPrefix("b/") ? String(path.dropFirst(2)) : path
                }
            } else if line.hasPrefix("@@") {
                hunkStartIndices.append(index)
            } else if line.hasPrefix("Binary files") || line.contains("Binary files") {
                isBinary = true
            }
        }

        // Determine file path and change type
        if oldPath == nil && newPath != nil {
            changeType = .created
            filePath = newPath!
        } else if oldPath != nil && newPath == nil {
            changeType = .deleted
            filePath = oldPath!
        } else if let np = newPath {
            filePath = np
            changeType = .modified
        } else {
            // Fallback: parse from the diff --git line
            let diffLine = lines[0]
            let parts = diffLine.components(separatedBy: " ")
            if parts.count >= 4 {
                let bPath = parts.last ?? ""
                filePath = bPath.hasPrefix("b/") ? String(bPath.dropFirst(2)) : bPath
            }
        }

        // Parse hunks
        var hunks: [DiffHunk] = []
        var totalAdded = 0
        var totalRemoved = 0

        for (i, hunkStart) in hunkStartIndices.enumerated() {
            let hunkEnd: Int
            if i + 1 < hunkStartIndices.count {
                hunkEnd = hunkStartIndices[i + 1]
            } else {
                hunkEnd = lines.count
            }

            let hunkLines = Array(lines[hunkStart..<hunkEnd])
            if let hunk = parseHunk(hunkLines) {
                for line in hunk.lines {
                    switch line.type {
                    case .addition:
                        totalAdded += 1
                    case .deletion:
                        totalRemoved += 1
                    case .context:
                        break
                    }
                }
                hunks.append(hunk)
            }
        }

        return GitFileDiff(
            filePath: filePath,
            changeType: changeType,
            hunks: hunks,
            linesAdded: totalAdded,
            linesRemoved: totalRemoved,
            isBinary: isBinary
        )
    }

    /// Parse a single hunk starting with an @@ line
    private static func parseHunk(_ lines: [String]) -> DiffHunk? {
        guard let headerLine = lines.first, headerLine.hasPrefix("@@") else {
            return nil
        }

        // Parse @@ -oldStart,oldCount +newStart,newCount @@
        let (oldStart, oldCount, newStart, newCount) = parseHunkHeader(headerLine)

        var hunkLines: [DiffHunkLine] = []
        var currentOldLine = oldStart
        var currentNewLine = newStart

        for line in lines.dropFirst() {
            if line.hasPrefix("+") {
                let content = String(line.dropFirst())
                hunkLines.append(DiffHunkLine(
                    type: .addition,
                    content: content,
                    oldLineNumber: nil,
                    newLineNumber: currentNewLine
                ))
                currentNewLine += 1
            } else if line.hasPrefix("-") {
                let content = String(line.dropFirst())
                hunkLines.append(DiffHunkLine(
                    type: .deletion,
                    content: content,
                    oldLineNumber: currentOldLine,
                    newLineNumber: nil
                ))
                currentOldLine += 1
            } else if line.hasPrefix(" ") {
                let content = String(line.dropFirst())
                hunkLines.append(DiffHunkLine(
                    type: .context,
                    content: content,
                    oldLineNumber: currentOldLine,
                    newLineNumber: currentNewLine
                ))
                currentOldLine += 1
                currentNewLine += 1
            } else if line.hasPrefix("\\") {
                // "\ No newline at end of file" - skip
                continue
            }
            // Other lines (empty, etc.) are ignored
        }

        return DiffHunk(
            oldStart: oldStart,
            oldCount: oldCount,
            newStart: newStart,
            newCount: newCount,
            header: headerLine,
            lines: hunkLines
        )
    }

    /// Parse the @@ header to extract line ranges
    private static func parseHunkHeader(_ header: String) -> (Int, Int, Int, Int) {
        // Format: @@ -oldStart,oldCount +newStart,newCount @@ optional context
        // Also handles @@ -oldStart +newStart @@ (count defaults to 1)
        var oldStart = 0
        var oldCount = 1
        var newStart = 0
        var newCount = 1

        // Find content between @@ markers
        let components = header.components(separatedBy: "@@")
        guard components.count >= 2 else {
            return (oldStart, oldCount, newStart, newCount)
        }

        let rangeStr = components[1].trimmingCharacters(in: .whitespaces)
        let parts = rangeStr.components(separatedBy: " ")

        for part in parts {
            if part.hasPrefix("-") {
                let range = String(part.dropFirst())
                let rangeParts = range.components(separatedBy: ",")
                oldStart = Int(rangeParts[0]) ?? 0
                if rangeParts.count > 1 {
                    oldCount = Int(rangeParts[1]) ?? 1
                }
            } else if part.hasPrefix("+") {
                let range = String(part.dropFirst())
                let rangeParts = range.components(separatedBy: ",")
                newStart = Int(rangeParts[0]) ?? 0
                if rangeParts.count > 1 {
                    newCount = Int(rangeParts[1]) ?? 1
                }
            }
        }

        return (oldStart, oldCount, newStart, newCount)
    }

    /// Create a diff entry for an untracked file (all content shown as additions)
    public static func createUntrackedFileDiff(path: String, content: String) -> GitFileDiff {
        let contentLines = content.components(separatedBy: "\n")
        // Remove trailing empty line from split if content ends with newline
        let lines: [String]
        if content.hasSuffix("\n") && contentLines.last == "" {
            lines = Array(contentLines.dropLast())
        } else {
            lines = contentLines
        }

        let hunkLines: [DiffHunkLine] = lines.enumerated().map { index, line in
            DiffHunkLine(
                type: .addition,
                content: line,
                oldLineNumber: nil,
                newLineNumber: index + 1
            )
        }

        let hunk = DiffHunk(
            oldStart: 0,
            oldCount: 0,
            newStart: 1,
            newCount: lines.count,
            header: "@@ -0,0 +1,\(lines.count) @@",
            lines: hunkLines
        )

        return GitFileDiff(
            filePath: path,
            changeType: .created,
            hunks: [hunk],
            linesAdded: lines.count,
            linesRemoved: 0,
            isBinary: false
        )
    }
}
