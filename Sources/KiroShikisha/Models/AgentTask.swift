import Foundation
#if canImport(Observation)
import Observation
#endif

/// A task representing a unit of work for an AI agent.
/// This is the first-class entity in the task-centric architecture,
/// replacing the previous workspace-centric approach.
#if canImport(Observation)
@Observable
@MainActor
public final class AgentTask: Identifiable {
    /// Unique identifier for this task
    public let id: UUID
    /// User-provided task name/description
    public var name: String
    /// Current status of the task
    public var status: TaskStatus
    /// The folder/workspace/worktree this task runs in
    public var workspacePath: URL
    /// Branch being worked on
    public var gitBranch: String?
    /// Whether to use a git worktree for isolated development
    public var useWorktree: Bool
    /// The branch name for the worktree
    public var worktreeBranchName: String?
    /// If task runs in a worktree, reference to the source workspace
    public var sourceWorkspaceId: UUID?
    /// Reference to the Agent running this task (nil if not started yet)
    public var agentId: UUID?
    /// ACP session ID
    public var sessionId: String?
    /// All files changed for this task
    public var fileChanges: [FileChange]
    /// When this task was created
    public let createdAt: Date
    /// When this task was started
    public var startedAt: Date?
    /// When this task was completed
    public var completedAt: Date?
    /// When the last activity occurred on this task
    public var lastActivityAt: Date?
    /// Why the task needs user input (e.g. "Agent is waiting for approval", "Error occurred")
    public var attentionReason: String?
    /// Conversation history for this task
    public var messages: [ChatMessage]

    public init(
        id: UUID = UUID(),
        name: String,
        status: TaskStatus = .pending,
        workspacePath: URL,
        gitBranch: String? = nil,
        useWorktree: Bool = false,
        worktreeBranchName: String? = nil,
        sourceWorkspaceId: UUID? = nil,
        agentId: UUID? = nil,
        sessionId: String? = nil,
        fileChanges: [FileChange] = [],
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        lastActivityAt: Date? = nil,
        attentionReason: String? = nil,
        messages: [ChatMessage] = []
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.workspacePath = workspacePath
        self.gitBranch = gitBranch
        self.useWorktree = useWorktree
        self.worktreeBranchName = worktreeBranchName
        self.sourceWorkspaceId = sourceWorkspaceId
        self.agentId = agentId
        self.sessionId = sessionId
        self.fileChanges = fileChanges
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.lastActivityAt = lastActivityAt
        self.attentionReason = attentionReason
        self.messages = messages
    }
}
#else
// Fallback for non-macOS platforms (Linux builds)
public final class AgentTask: Identifiable {
    public let id: UUID
    public var name: String
    public var status: TaskStatus
    public var workspacePath: URL
    public var gitBranch: String?
    public var useWorktree: Bool
    public var worktreeBranchName: String?
    public var sourceWorkspaceId: UUID?
    public var agentId: UUID?
    public var sessionId: String?
    public var fileChanges: [FileChange]
    public let createdAt: Date
    public var startedAt: Date?
    public var completedAt: Date?
    public var lastActivityAt: Date?
    public var attentionReason: String?
    public var messages: [ChatMessage]

    public init(
        id: UUID = UUID(),
        name: String,
        status: TaskStatus = .pending,
        workspacePath: URL,
        gitBranch: String? = nil,
        useWorktree: Bool = false,
        worktreeBranchName: String? = nil,
        sourceWorkspaceId: UUID? = nil,
        agentId: UUID? = nil,
        sessionId: String? = nil,
        fileChanges: [FileChange] = [],
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        lastActivityAt: Date? = nil,
        attentionReason: String? = nil,
        messages: [ChatMessage] = []
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.workspacePath = workspacePath
        self.gitBranch = gitBranch
        self.useWorktree = useWorktree
        self.worktreeBranchName = worktreeBranchName
        self.sourceWorkspaceId = sourceWorkspaceId
        self.agentId = agentId
        self.sessionId = sessionId
        self.fileChanges = fileChanges
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.lastActivityAt = lastActivityAt
        self.attentionReason = attentionReason
        self.messages = messages
    }
}
#endif

/// Request to create a new task
public struct TaskCreationRequest: Sendable {
    /// User-provided task name/description
    public let name: String
    /// The folder/workspace path for this task
    public let workspacePath: URL
    /// Optional branch to work on
    public let gitBranch: String?
    /// Whether to use a git worktree for isolated development
    public let useWorktree: Bool
    /// The branch name for the worktree
    public let worktreeBranchName: String?
    /// Whether to start the task immediately after creation
    public let startImmediately: Bool

    public init(
        name: String,
        workspacePath: URL,
        gitBranch: String? = nil,
        useWorktree: Bool = false,
        worktreeBranchName: String? = nil,
        startImmediately: Bool = true
    ) {
        self.name = name
        self.workspacePath = workspacePath
        self.gitBranch = gitBranch
        self.useWorktree = useWorktree
        self.worktreeBranchName = worktreeBranchName
        self.startImmediately = startImmediately
    }
}
