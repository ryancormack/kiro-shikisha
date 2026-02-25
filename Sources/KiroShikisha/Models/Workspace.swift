import Foundation

/// Represents a workspace (project directory) that an agent can operate on
public struct Workspace: Identifiable, Codable, Hashable, Sendable {
    /// Unique identifier for this workspace
    public let id: UUID
    /// Human-readable name for the workspace
    public var name: String
    /// Path to the workspace directory
    public var path: URL
    /// Optional Git repository URL
    public var gitRepository: URL?
    /// Optional Git branch name
    public var gitBranch: String?
    /// Optional Git worktree path (for parallel development on the same repo)
    public var gitWorktreePath: URL?
    /// ID of the source workspace this was forked from (for worktrees)
    public var sourceWorkspaceId: UUID?
    /// When this workspace was created
    public let createdAt: Date
    /// When this workspace was last accessed
    public var lastAccessedAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        gitRepository: URL? = nil,
        gitBranch: String? = nil,
        gitWorktreePath: URL? = nil,
        sourceWorkspaceId: UUID? = nil,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.gitRepository = gitRepository
        self.gitBranch = gitBranch
        self.gitWorktreePath = gitWorktreePath
        self.sourceWorkspaceId = sourceWorkspaceId
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
    }
}
