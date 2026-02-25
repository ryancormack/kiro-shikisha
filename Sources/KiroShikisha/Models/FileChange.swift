import Foundation

/// Type of change made to a file
public enum FileChangeType: String, Codable, Sendable {
    case created
    case modified
    case deleted
}

/// Represents a file change made by an agent
public struct FileChange: Identifiable, Equatable, Sendable {
    /// Unique identifier for this change
    public let id: UUID
    /// File path relative to workspace
    public let path: String
    /// Original content before the change (nil for created files)
    public let oldContent: String?
    /// New content after the change
    public let newContent: String
    /// Type of change (created, modified, deleted)
    public let changeType: FileChangeType
    /// Associated tool call ID (links to the tool call that made this change)
    public let toolCallId: String?
    /// When this change occurred
    public let timestamp: Date
    
    /// Number of lines added in this change
    public var linesAdded: Int {
        let newLines = newContent.components(separatedBy: .newlines)
        let oldLines = oldContent?.components(separatedBy: .newlines) ?? []
        
        // Simple line diff: count lines in new that aren't in old
        var added = 0
        for line in newLines {
            if !oldLines.contains(line) && !line.isEmpty {
                added += 1
            }
        }
        return added
    }
    
    /// Number of lines removed in this change
    public var linesRemoved: Int {
        guard let oldContent = oldContent else { return 0 }
        
        let newLines = newContent.components(separatedBy: .newlines)
        let oldLines = oldContent.components(separatedBy: .newlines)
        
        // Simple line diff: count lines in old that aren't in new
        var removed = 0
        for line in oldLines {
            if !newLines.contains(line) && !line.isEmpty {
                removed += 1
            }
        }
        return removed
    }
    
    /// File name extracted from path
    public var fileName: String {
        (path as NSString).lastPathComponent
    }
    
    /// Directory path extracted from path
    public var directoryPath: String {
        (path as NSString).deletingLastPathComponent
    }
    
    public init(
        id: UUID = UUID(),
        path: String,
        oldContent: String? = nil,
        newContent: String,
        changeType: FileChangeType,
        toolCallId: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.path = path
        self.oldContent = oldContent
        self.newContent = newContent
        self.changeType = changeType
        self.toolCallId = toolCallId
        self.timestamp = timestamp
    }
}
