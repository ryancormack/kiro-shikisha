#if os(macOS)
import SwiftUI

/// Row displaying a single file change with status, colored accent, and mini change bar
struct FileChangeRow: View {
    let fileDiff: GitFileDiff
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Colored left-border accent
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accentColor)
                .frame(width: 3, height: 24)
                .padding(.trailing, DesignConstants.spacingSM)

            // File icon
            Image(systemName: fileIcon)
                .foregroundColor(iconColor)
                .frame(width: 16)
                .padding(.trailing, DesignConstants.spacingSM)

            // File path info
            VStack(alignment: .leading, spacing: 2) {
                Text(fileDiff.fileName)
                    .font(.subheadline)
                    .lineLimit(1)

                if !fileDiff.directoryPath.isEmpty {
                    Text(fileDiff.directoryPath)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Line change indicators
            HStack(spacing: DesignConstants.spacingXS) {
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
            .padding(.trailing, DesignConstants.spacingSM)

            // Mini change bar (GitHub-style)
            miniChangeBar
                .padding(.trailing, DesignConstants.spacingSM)

            // Change type badge
            Image(systemName: changeTypeIcon)
                .foregroundColor(changeTypeColor)
                .font(.caption)
        }
        .padding(.vertical, DesignConstants.spacingXS)
        .contentShape(Rectangle())
    }

    // MARK: - Mini Change Bar

    private var miniChangeBar: some View {
        let total = fileDiff.linesAdded + fileDiff.linesRemoved
        let addedFraction = total > 0 ? CGFloat(fileDiff.linesAdded) / CGFloat(total) : 0.5

        return HStack(spacing: 1) {
            if fileDiff.linesAdded > 0 {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.green)
                    .frame(width: max(2, 40 * addedFraction), height: 6)
            }
            if fileDiff.linesRemoved > 0 {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.red)
                    .frame(width: max(2, 40 * (1 - addedFraction)), height: 6)
            }
        }
        .frame(width: 40, alignment: .leading)
    }

    // MARK: - Accent Color

    private var accentColor: Color {
        switch fileDiff.changeType {
        case .created:
            return .green
        case .modified:
            return .yellow
        case .deleted:
            return .red
        }
    }

    // MARK: - Private Helpers

    private var fileIcon: String {
        let ext = (fileDiff.filePath as NSString).pathExtension.lowercased()
        switch ext {
        case "swift":
            return "swift"
        case "js", "ts", "jsx", "tsx":
            return "doc.text"
        case "json":
            return "curlybraces"
        case "md", "markdown":
            return "doc.richtext"
        case "html", "htm":
            return "chevron.left.forwardslash.chevron.right"
        case "css", "scss":
            return "paintbrush"
        case "py":
            return "chevron.left.forwardslash.chevron.right"
        case "rs":
            return "gearshape.2"
        case "yml", "yaml":
            return "list.bullet.rectangle"
        case "sh", "bash", "zsh":
            return "terminal"
        case "xml", "plist":
            return "doc.text"
        case "c", "cpp", "h", "hpp":
            return "chevron.left.forwardslash.chevron.right"
        case "go":
            return "chevron.left.forwardslash.chevron.right"
        case "rb":
            return "diamond"
        case "toml":
            return "list.bullet.rectangle"
        case "lock":
            return "lock"
        case "png", "jpg", "jpeg", "gif", "svg", "webp":
            return "photo"
        default:
            return "doc"
        }
    }

    private var iconColor: Color {
        let ext = (fileDiff.filePath as NSString).pathExtension.lowercased()
        switch ext {
        case "swift":
            return .orange
        case "js", "ts", "jsx", "tsx":
            return .yellow
        case "json":
            return .purple
        case "md", "markdown":
            return .blue
        case "py":
            return .green
        case "rs":
            return .orange
        case "rb":
            return .red
        case "go":
            return .cyan
        default:
            return .secondary
        }
    }

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

#Preview {
    VStack(spacing: 8) {
        FileChangeRow(
            fileDiff: GitFileDiff(
                filePath: "Sources/main.swift",
                changeType: .modified,
                linesAdded: 12,
                linesRemoved: 3
            ),
            isSelected: false
        )

        FileChangeRow(
            fileDiff: GitFileDiff(
                filePath: "Sources/Helper/NewFile.swift",
                changeType: .created,
                linesAdded: 25,
                linesRemoved: 0
            ),
            isSelected: true
        )

        FileChangeRow(
            fileDiff: GitFileDiff(
                filePath: "README.md",
                changeType: .deleted,
                linesAdded: 0,
                linesRemoved: 10
            ),
            isSelected: false
        )

        FileChangeRow(
            fileDiff: GitFileDiff(
                filePath: "Package.swift",
                changeType: .modified,
                linesAdded: 3,
                linesRemoved: 3
            ),
            isSelected: false
        )
    }
    .padding()
    .frame(width: 500, height: 300)
}
#endif
