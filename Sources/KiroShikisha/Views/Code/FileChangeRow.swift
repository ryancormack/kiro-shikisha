#if os(macOS)
import SwiftUI

/// Row displaying a single file change with status and line counts
struct FileChangeRow: View {
    let fileChange: FileChange
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // File icon
            Image(systemName: fileIcon)
                .foregroundColor(iconColor)
                .frame(width: 16)
            
            // File path info
            VStack(alignment: .leading, spacing: 2) {
                Text(fileChange.fileName)
                    .font(.subheadline)
                    .lineLimit(1)
                
                if !fileChange.directoryPath.isEmpty {
                    Text(fileChange.directoryPath)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Line change indicators
            HStack(spacing: 4) {
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
            
            // Change type icon
            Image(systemName: changeTypeIcon)
                .foregroundColor(changeTypeColor)
                .font(.caption)
            
            // Disclosure indicator
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    
    // MARK: - Private Helpers
    
    private var fileIcon: String {
        let ext = (fileChange.path as NSString).pathExtension.lowercased()
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
        default:
            return "doc"
        }
    }
    
    private var iconColor: Color {
        let ext = (fileChange.path as NSString).pathExtension.lowercased()
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
        default:
            return .secondary
        }
    }
    
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

#Preview {
    VStack(spacing: 8) {
        FileChangeRow(
            fileChange: FileChange(
                path: "Sources/main.swift",
                oldContent: "let x = 1",
                newContent: "let x = 2\nlet y = 3",
                changeType: .modified
            ),
            isSelected: false
        )
        
        FileChangeRow(
            fileChange: FileChange(
                path: "Sources/Helper/NewFile.swift",
                newContent: "// New file\nfunc helper() {}",
                changeType: .created
            ),
            isSelected: true
        )
        
        FileChangeRow(
            fileChange: FileChange(
                path: "README.md",
                oldContent: "# Old content\nSome text here",
                newContent: "",
                changeType: .deleted
            ),
            isSelected: false
        )
    }
    .padding()
    .frame(width: 300)
}
#endif
