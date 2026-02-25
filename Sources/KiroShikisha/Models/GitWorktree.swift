import Foundation

/// Represents a Git worktree (main or linked)
public struct GitWorktree: Identifiable, Equatable, Hashable, Sendable {
    /// Unique identifier for this worktree instance
    public let id: UUID
    /// Path to the worktree directory
    public let path: URL
    /// The branch checked out in this worktree
    public let branch: String
    /// The HEAD commit hash
    public let commitHash: String
    /// True if this is the main worktree (not a linked worktree)
    public let isMain: Bool
    
    public init(
        id: UUID = UUID(),
        path: URL,
        branch: String,
        commitHash: String,
        isMain: Bool
    ) {
        self.id = id
        self.path = path
        self.branch = branch
        self.commitHash = commitHash
        self.isMain = isMain
    }
}
