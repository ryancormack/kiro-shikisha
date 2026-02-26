#if os(macOS)
import SwiftUI

/// Line type for diff display
enum DiffLineType {
    case context
    case addition
    case deletion
}

/// A single line in a unified diff
struct DiffLine: Identifiable {
    let id = UUID()
    let type: DiffLineType
    let content: String
    let oldLineNumber: Int?
    let newLineNumber: Int?
}

/// Unified diff view showing file changes with line numbers and color-coded additions/deletions
struct DiffView: View {
    let fileChange: FileChange
    
    /// Context lines to show around changes
    private let contextLines = 3
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // File header
            HStack {
                Image(systemName: changeTypeIcon)
                    .foregroundColor(changeTypeColor)
                Text(fileChange.path)
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
                HStack(spacing: 8) {
                    if fileChange.linesAdded > 0 {
                        Text("+\(fileChange.linesAdded)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    if fileChange.linesRemoved > 0 {
                        Text("-\(fileChange.linesRemoved)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Diff content
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(diffLines) { line in
                        DiffLineView(line: line)
                    }
                }
            }
        }
        .font(.system(.body, design: .monospaced))
    }
    
    // MARK: - Diff Algorithm
    
    private var diffLines: [DiffLine] {
        let oldLines = fileChange.oldContent?.components(separatedBy: "\n") ?? []
        let newLines = fileChange.newContent.components(separatedBy: "\n")
        
        // If it's a new file, show all as additions
        if fileChange.changeType == .created {
            return newLines.enumerated().map { index, line in
                DiffLine(type: .addition, content: line, oldLineNumber: nil, newLineNumber: index + 1)
            }
        }
        
        // If it's a deleted file, show all as deletions
        if fileChange.changeType == .deleted {
            return oldLines.enumerated().map { index, line in
                DiffLine(type: .deletion, content: line, oldLineNumber: index + 1, newLineNumber: nil)
            }
        }
        
        // Compute LCS-based diff for modified files
        return computeUnifiedDiff(oldLines: oldLines, newLines: newLines)
    }
    
    /// Compute unified diff using longest common subsequence approach
    private func computeUnifiedDiff(oldLines: [String], newLines: [String]) -> [DiffLine] {
        let lcs = longestCommonSubsequence(oldLines, newLines)
        var result: [DiffLine] = []
        
        var oldIndex = 0
        var newIndex = 0
        var lcsIndex = 0
        
        while oldIndex < oldLines.count || newIndex < newLines.count {
            if lcsIndex < lcs.count {
                let (lcsOldIdx, lcsNewIdx) = lcs[lcsIndex]
                
                // Add deletions (lines in old but not in LCS)
                while oldIndex < lcsOldIdx && oldIndex < oldLines.count {
                    result.append(DiffLine(
                        type: .deletion,
                        content: oldLines[oldIndex],
                        oldLineNumber: oldIndex + 1,
                        newLineNumber: nil
                    ))
                    oldIndex += 1
                }
                
                // Add additions (lines in new but not in LCS)
                while newIndex < lcsNewIdx && newIndex < newLines.count {
                    result.append(DiffLine(
                        type: .addition,
                        content: newLines[newIndex],
                        oldLineNumber: nil,
                        newLineNumber: newIndex + 1
                    ))
                    newIndex += 1
                }
                
                // Add context line (common line)
                if oldIndex < oldLines.count && newIndex < newLines.count {
                    result.append(DiffLine(
                        type: .context,
                        content: oldLines[oldIndex],
                        oldLineNumber: oldIndex + 1,
                        newLineNumber: newIndex + 1
                    ))
                }
                oldIndex += 1
                newIndex += 1
                lcsIndex += 1
            } else {
                // After LCS is exhausted, add remaining deletions and additions
                while oldIndex < oldLines.count {
                    result.append(DiffLine(
                        type: .deletion,
                        content: oldLines[oldIndex],
                        oldLineNumber: oldIndex + 1,
                        newLineNumber: nil
                    ))
                    oldIndex += 1
                }
                
                while newIndex < newLines.count {
                    result.append(DiffLine(
                        type: .addition,
                        content: newLines[newIndex],
                        oldLineNumber: nil,
                        newLineNumber: newIndex + 1
                    ))
                    newIndex += 1
                }
            }
        }
        
        return result
    }
    
    /// Compute longest common subsequence, returning indices of matching lines
    private func longestCommonSubsequence(_ old: [String], _ new: [String]) -> [(Int, Int)] {
        let m = old.count
        let n = new.count
        
        guard m > 0 && n > 0 else { return [] }
        
        // Build LCS matrix
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 1...m {
            for j in 1...n {
                if old[i - 1] == new[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }
        
        // Backtrack to find the actual subsequence
        var result: [(Int, Int)] = []
        var i = m
        var j = n
        
        while i > 0 && j > 0 {
            if old[i - 1] == new[j - 1] {
                result.append((i - 1, j - 1))
                i -= 1
                j -= 1
            } else if dp[i - 1][j] > dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        
        return result.reversed()
    }
    
    // MARK: - Helpers
    
    private var changeTypeIcon: String {
        switch fileChange.changeType {
        case .created:
            return "plus.circle.fill"
        case .modified:
            return "pencil.circle.fill"
        case .deleted:
            return "minus.circle.fill"
        }
    }
    
    private var changeTypeColor: Color {
        switch fileChange.changeType {
        case .created:
            return .green
        case .modified:
            return .yellow
        case .deleted:
            return .red
        }
    }
}

/// View for a single diff line
struct DiffLineView: View {
    let line: DiffLine
    
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
    DiffView(fileChange: FileChange(
        path: "Sources/main.swift",
        oldContent: """
        import Foundation
        
        let x = 1
        let y = 2
        
        func main() {
            print("Hello")
        }
        """,
        newContent: """
        import Foundation
        import SwiftUI
        
        let x = 1
        let y = 3
        let z = 4
        
        func main() {
            print("Hello, World!")
        }
        
        func helper() {
            // Added helper
        }
        """,
        changeType: .modified
    ))
    .frame(width: 600, height: 400)
}

#Preview("New File") {
    DiffView(fileChange: FileChange(
        path: "Sources/NewFile.swift",
        newContent: """
        import Foundation
        
        struct NewFile {
            let value: Int
        }
        """,
        changeType: .created
    ))
    .frame(width: 600, height: 300)
}

#Preview("Deleted File") {
    DiffView(fileChange: FileChange(
        path: "Sources/OldFile.swift",
        oldContent: """
        // This file is being deleted
        let legacy = true
        """,
        newContent: "",
        changeType: .deleted
    ))
    .frame(width: 600, height: 200)
}
#endif
