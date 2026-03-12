import Foundation
#if canImport(Observation)
import Observation
#endif

#if os(macOS)

/// Service that manages AgentTask lifecycle
@Observable
@MainActor
public final class TaskManager {
    /// All managed tasks indexed by their ID
    public private(set) var tasks: [UUID: AgentTask] = [:]

    /// Reference to the agent manager for starting/stopping agents
    public var agentManager: AgentManager?

    /// Reference to the app state manager for reactive persistence
    public var appStateManager: AppStateManager?

    // MARK: - Computed Properties

    /// Tasks that are currently active (starting, working, or needs attention)
    public var activeTasks: [AgentTask] {
        tasks.values.filter { $0.status.isActive }
    }

    /// Tasks that need user attention
    public var tasksNeedingAttention: [AgentTask] {
        tasks.values.filter { $0.status == .needsAttention }
    }

    /// Tasks that have reached a terminal state
    public var completedTasks: [AgentTask] {
        tasks.values.filter { $0.status.isTerminal }
    }

    /// All tasks as an array
    public var allTasks: [AgentTask] {
        Array(tasks.values)
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Persistence Helper

    /// Persists the current task state via the app state manager
    private func persistCurrentState() {
        appStateManager?.persistTasks(allTasks)
    }

    // MARK: - Task Lifecycle

    /// Creates a new task from a creation request
    /// - Parameter request: The task creation request
    /// - Returns: The newly created task
    public func createTask(from request: TaskCreationRequest) -> AgentTask {
        let task = AgentTask(
            name: request.name,
            status: .pending,
            workspacePath: request.workspacePath,
            gitBranch: request.gitBranch,
            useWorktree: request.useWorktree,
            worktreeBranchName: request.worktreeBranchName
        )
        tasks[task.id] = task
        persistCurrentState()
        return task
    }

    /// Starts a task by creating a workspace and launching an agent
    /// - Parameter id: The task ID to start
    public func startTask(id: UUID) async throws {
        guard let task = tasks[id] else { return }
        guard let agentManager = agentManager else {
            throw AgentManagerError.platformNotSupported
        }

        task.status = .starting
        task.startedAt = Date()

        // If worktree requested, create it and update the task's workspace path
        if task.useWorktree, let branchName = task.worktreeBranchName {
            let gitService = GitService()
            guard let repo = try await gitService.detectGitRepository(at: task.workspacePath) else {
                task.status = .failed
                throw AgentManagerError.notAGitRepository
            }

            let worktreePath = task.workspacePath
                .deletingLastPathComponent()
                .appendingPathComponent("\(task.workspacePath.lastPathComponent)-\(branchName)")

            let worktree = try await gitService.createWorktree(
                repository: repo,
                branch: branchName,
                path: worktreePath
            )

            // Update task to use the worktree directory
            task.workspacePath = worktree.path
            task.gitBranch = branchName
        }

        let workspace = Workspace(
            name: task.name,
            path: task.workspacePath,
            gitBranch: task.gitBranch
        )

        let agent = try await agentManager.startAgent(workspace: workspace)
        task.agentId = agent.id
        task.sessionId = agent.sessionId?.value
        task.status = .working
        task.lastActivityAt = Date()
        persistCurrentState()
    }

    /// Pauses a task
    /// - Parameter id: The task ID to pause
    public func pauseTask(id: UUID) {
        guard let task = tasks[id] else { return }
        task.status = .paused
        task.lastActivityAt = Date()
        persistCurrentState()
    }

    /// Resumes a paused task
    /// - Parameter id: The task ID to resume
    public func resumeTask(id: UUID) async throws {
        guard let task = tasks[id] else { return }
        guard let agentManager = agentManager else {
            throw AgentManagerError.platformNotSupported
        }

        // If we already have an active agent, just resume
        if let agentId = task.agentId, agentManager.getAgent(id: agentId) != nil {
            task.status = .working
            task.lastActivityAt = Date()
            persistCurrentState()
            return
        }

        // Need to reconnect - must have a session ID
        guard let sessionId = task.sessionId else {
            // No session to reconnect to - just set working status
            task.status = .working
            task.lastActivityAt = Date()
            persistCurrentState()
            return
        }

        task.status = .starting
        task.lastActivityAt = Date()

        let workspace = Workspace(
            name: task.name,
            path: task.workspacePath,
            gitBranch: task.gitBranch
        )

        let agent = try await agentManager.loadAgent(workspace: workspace, sessionId: sessionId)
        task.agentId = agent.id
        task.status = .working

        // Load conversation history from session storage
        let sessionStorage = SessionStorage()
        if let messages = try? sessionStorage.loadSessionHistory(sessionId: sessionId), !messages.isEmpty {
            task.messages = messages
        }

        task.lastActivityAt = Date()
        persistCurrentState()
    }

    /// Cancels a task and stops its agent if running
    /// - Parameter id: The task ID to cancel
    public func cancelTask(id: UUID) async {
        guard let task = tasks[id] else { return }
        task.status = .cancelled
        task.lastActivityAt = Date()

        if let agentId = task.agentId {
            await agentManager?.stopAgent(id: agentId)
        }
        persistCurrentState()
    }

    /// Marks a task as completed
    /// - Parameter id: The task ID to complete
    public func completeTask(id: UUID) {
        guard let task = tasks[id] else { return }
        task.status = .completed
        task.completedAt = Date()
        task.lastActivityAt = Date()
        persistCurrentState()
    }

    /// Marks a task as needing user attention
    /// - Parameters:
    ///   - id: The task ID
    ///   - reason: Why the task needs attention
    public func markNeedsAttention(id: UUID, reason: String) {
        guard let task = tasks[id] else { return }
        task.status = .needsAttention
        task.attentionReason = reason
        task.lastActivityAt = Date()
        persistCurrentState()
    }

    /// Clears the attention state and returns to working
    /// - Parameter id: The task ID
    public func clearAttention(id: UUID) {
        guard let task = tasks[id] else { return }
        task.attentionReason = nil
        task.status = .working
        task.lastActivityAt = Date()
        persistCurrentState()
    }

    /// Syncs task state from the agent's current state
    /// - Parameter taskId: The task ID to sync
    public func syncFromAgent(taskId: UUID) {
        guard let task = tasks[taskId],
              let agentId = task.agentId,
              let agent = agentManager?.getAgent(id: agentId) else { return }

        task.fileChanges = agent.fileChanges
        task.messages = agent.messages
        task.lastActivityAt = Date()
    }

    /// Gets a task by ID
    /// - Parameter id: The task ID
    /// - Returns: The task if found
    public func getTask(id: UUID) -> AgentTask? {
        return tasks[id]
    }

    /// Deletes a task and stops its agent if running
    /// - Parameter id: The task ID to delete
    public func deleteTask(id: UUID) async {
        if let task = tasks[id], let agentId = task.agentId {
            await agentManager?.stopAgent(id: agentId)
        }
        tasks.removeValue(forKey: id)
        persistCurrentState()
    }

    /// Restores tasks from persisted entries
    /// Active tasks are restored as paused; terminal tasks remain as-is
    public func restoreTasks(from entries: [AppStateManager.TaskPersistenceEntry]) {
        for entry in entries {
            let status = TaskStatus(rawValue: entry.statusRawValue) ?? .pending
            let restoredStatus: TaskStatus
            if status.isActive {
                restoredStatus = .paused
            } else {
                restoredStatus = status
            }
            let task = AgentTask(
                id: entry.id,
                name: entry.name,
                status: restoredStatus,
                workspacePath: URL(fileURLWithPath: entry.workspacePath),
                gitBranch: entry.gitBranch,
                createdAt: entry.createdAt,
                completedAt: entry.completedAt,
                lastActivityAt: entry.lastActivityAt
            )
            task.sessionId = entry.sessionId
            tasks[task.id] = task
        }
        persistCurrentState()
    }

    /// Re-opens a previously persisted task by loading its ACP session
    public func reopenTask(id: UUID) async throws {
        guard let task = tasks[id] else { return }
        guard let sessionId = task.sessionId else {
            throw AgentManagerError.noSessionId
        }
        guard let agentManager = agentManager else {
            throw AgentManagerError.platformNotSupported
        }

        task.status = .starting
        task.lastActivityAt = Date()

        let workspace = Workspace(
            name: task.name,
            path: task.workspacePath,
            gitBranch: task.gitBranch
        )

        let agent = try await agentManager.loadAgent(workspace: workspace, sessionId: sessionId)
        task.agentId = agent.id
        task.status = .working

        // Load conversation history from session storage
        let sessionStorage = SessionStorage()
        if let messages = try? sessionStorage.loadSessionHistory(sessionId: sessionId), !messages.isEmpty {
            task.messages = messages
        }

        task.lastActivityAt = Date()
        persistCurrentState()
    }
}

#else

// Stub implementation for non-macOS platforms (Linux)
#if canImport(Observation)
@Observable
@MainActor
public final class TaskManager {
    public private(set) var tasks: [UUID: AgentTask] = [:]
    public var agentManager: AgentManager?
    public var appStateManager: AppStateManager?

    public var activeTasks: [AgentTask] {
        tasks.values.filter { $0.status.isActive }
    }
    public var tasksNeedingAttention: [AgentTask] {
        tasks.values.filter { $0.status == .needsAttention }
    }
    public var completedTasks: [AgentTask] {
        tasks.values.filter { $0.status.isTerminal }
    }
    public var allTasks: [AgentTask] {
        Array(tasks.values)
    }

    public init() {}

    private func persistCurrentState() {
        appStateManager?.persistTasks(allTasks)
    }

    public func createTask(from request: TaskCreationRequest) -> AgentTask {
        let task = AgentTask(
            name: request.name,
            status: .pending,
            workspacePath: request.workspacePath,
            gitBranch: request.gitBranch,
            useWorktree: request.useWorktree,
            worktreeBranchName: request.worktreeBranchName
        )
        tasks[task.id] = task
        persistCurrentState()
        return task
    }

    public func startTask(id: UUID) async throws {
        throw AgentManagerError.platformNotSupported
    }

    public func pauseTask(id: UUID) {
        guard let task = tasks[id] else { return }
        task.status = .paused
        task.lastActivityAt = Date()
        persistCurrentState()
    }

    public func resumeTask(id: UUID) async throws {
        throw AgentManagerError.platformNotSupported
    }

    public func cancelTask(id: UUID) async {
        guard let task = tasks[id] else { return }
        task.status = .cancelled
        task.lastActivityAt = Date()
        persistCurrentState()
    }

    public func completeTask(id: UUID) {
        guard let task = tasks[id] else { return }
        task.status = .completed
        task.completedAt = Date()
        task.lastActivityAt = Date()
        persistCurrentState()
    }

    public func markNeedsAttention(id: UUID, reason: String) {
        guard let task = tasks[id] else { return }
        task.status = .needsAttention
        task.attentionReason = reason
        task.lastActivityAt = Date()
        persistCurrentState()
    }

    public func clearAttention(id: UUID) {
        guard let task = tasks[id] else { return }
        task.attentionReason = nil
        task.status = .working
        task.lastActivityAt = Date()
        persistCurrentState()
    }

    public func syncFromAgent(taskId: UUID) {
        // No-op on non-macOS
    }

    public func getTask(id: UUID) -> AgentTask? {
        return tasks[id]
    }

    public func deleteTask(id: UUID) async {
        tasks.removeValue(forKey: id)
        persistCurrentState()
    }

    public func restoreTasks(from entries: [AppStateManager.TaskPersistenceEntry]) {
        for entry in entries {
            let status = TaskStatus(rawValue: entry.statusRawValue) ?? .pending
            let restoredStatus: TaskStatus
            if status.isActive {
                restoredStatus = .paused
            } else {
                restoredStatus = status
            }
            let task = AgentTask(
                id: entry.id,
                name: entry.name,
                status: restoredStatus,
                workspacePath: URL(fileURLWithPath: entry.workspacePath),
                gitBranch: entry.gitBranch,
                createdAt: entry.createdAt,
                completedAt: entry.completedAt,
                lastActivityAt: entry.lastActivityAt
            )
            task.sessionId = entry.sessionId
            tasks[task.id] = task
        }
        persistCurrentState()
    }

    public func reopenTask(id: UUID) async throws {
        throw AgentManagerError.platformNotSupported
    }
}
#else
// Fallback for platforms without Observation framework
@MainActor
public final class TaskManager {
    public private(set) var tasks: [UUID: AgentTask] = [:]
    public var agentManager: AgentManager?
    public var appStateManager: AppStateManager?

    public var activeTasks: [AgentTask] {
        tasks.values.filter { $0.status.isActive }
    }
    public var tasksNeedingAttention: [AgentTask] {
        tasks.values.filter { $0.status == .needsAttention }
    }
    public var completedTasks: [AgentTask] {
        tasks.values.filter { $0.status.isTerminal }
    }
    public var allTasks: [AgentTask] {
        Array(tasks.values)
    }

    public init() {}

    private func persistCurrentState() {
        appStateManager?.persistTasks(allTasks)
    }

    public func createTask(from request: TaskCreationRequest) -> AgentTask {
        let task = AgentTask(
            name: request.name,
            status: .pending,
            workspacePath: request.workspacePath,
            gitBranch: request.gitBranch,
            useWorktree: request.useWorktree,
            worktreeBranchName: request.worktreeBranchName
        )
        tasks[task.id] = task
        persistCurrentState()
        return task
    }

    public func startTask(id: UUID) async throws {
        throw AgentManagerError.platformNotSupported
    }

    public func pauseTask(id: UUID) {
        guard let task = tasks[id] else { return }
        task.status = .paused
        task.lastActivityAt = Date()
        persistCurrentState()
    }

    public func resumeTask(id: UUID) async throws {
        throw AgentManagerError.platformNotSupported
    }

    public func cancelTask(id: UUID) async {
        guard let task = tasks[id] else { return }
        task.status = .cancelled
        task.lastActivityAt = Date()
        persistCurrentState()
    }

    public func completeTask(id: UUID) {
        guard let task = tasks[id] else { return }
        task.status = .completed
        task.completedAt = Date()
        task.lastActivityAt = Date()
        persistCurrentState()
    }

    public func markNeedsAttention(id: UUID, reason: String) {
        guard let task = tasks[id] else { return }
        task.status = .needsAttention
        task.attentionReason = reason
        task.lastActivityAt = Date()
        persistCurrentState()
    }

    public func clearAttention(id: UUID) {
        guard let task = tasks[id] else { return }
        task.attentionReason = nil
        task.status = .working
        task.lastActivityAt = Date()
        persistCurrentState()
    }

    public func syncFromAgent(taskId: UUID) {
        // No-op on non-macOS
    }

    public func getTask(id: UUID) -> AgentTask? {
        return tasks[id]
    }

    public func deleteTask(id: UUID) async {
        tasks.removeValue(forKey: id)
        persistCurrentState()
    }

    public func restoreTasks(from entries: [AppStateManager.TaskPersistenceEntry]) {
        for entry in entries {
            let status = TaskStatus(rawValue: entry.statusRawValue) ?? .pending
            let restoredStatus: TaskStatus
            if status.isActive {
                restoredStatus = .paused
            } else {
                restoredStatus = status
            }
            let task = AgentTask(
                id: entry.id,
                name: entry.name,
                status: restoredStatus,
                workspacePath: URL(fileURLWithPath: entry.workspacePath),
                gitBranch: entry.gitBranch,
                createdAt: entry.createdAt,
                completedAt: entry.completedAt,
                lastActivityAt: entry.lastActivityAt
            )
            task.sessionId = entry.sessionId
            tasks[task.id] = task
        }
        persistCurrentState()
    }

    public func reopenTask(id: UUID) async throws {
        throw AgentManagerError.platformNotSupported
    }
}
#endif

#endif
