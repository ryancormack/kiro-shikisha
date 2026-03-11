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

    // MARK: - Task Lifecycle

    /// Creates a new task from a creation request
    /// - Parameter request: The task creation request
    /// - Returns: The newly created task
    public func createTask(from request: TaskCreationRequest) -> AgentTask {
        let task = AgentTask(
            name: request.name,
            status: .pending,
            workspacePath: request.workspacePath,
            gitBranch: request.gitBranch
        )
        tasks[task.id] = task
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
    }

    /// Pauses a task
    /// - Parameter id: The task ID to pause
    public func pauseTask(id: UUID) {
        guard let task = tasks[id] else { return }
        task.status = .paused
        task.lastActivityAt = Date()
    }

    /// Resumes a paused task
    /// - Parameter id: The task ID to resume
    public func resumeTask(id: UUID) async throws {
        guard let task = tasks[id] else { return }
        task.status = .working
        task.lastActivityAt = Date()
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
    }

    /// Marks a task as completed
    /// - Parameter id: The task ID to complete
    public func completeTask(id: UUID) {
        guard let task = tasks[id] else { return }
        task.status = .completed
        task.completedAt = Date()
        task.lastActivityAt = Date()
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
    }

    /// Clears the attention state and returns to working
    /// - Parameter id: The task ID
    public func clearAttention(id: UUID) {
        guard let task = tasks[id] else { return }
        task.attentionReason = nil
        task.status = .working
        task.lastActivityAt = Date()
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

    public var activeTasks: [AgentTask] { [] }
    public var tasksNeedingAttention: [AgentTask] { [] }
    public var completedTasks: [AgentTask] { [] }
    public var allTasks: [AgentTask] { [] }

    public init() {}

    public func createTask(from request: TaskCreationRequest) -> AgentTask {
        let task = AgentTask(
            name: request.name,
            status: .pending,
            workspacePath: request.workspacePath,
            gitBranch: request.gitBranch
        )
        return task
    }

    public func startTask(id: UUID) async throws {
        throw AgentManagerError.platformNotSupported
    }

    public func pauseTask(id: UUID) {
        // No-op on non-macOS
    }

    public func resumeTask(id: UUID) async throws {
        throw AgentManagerError.platformNotSupported
    }

    public func cancelTask(id: UUID) async {
        // No-op on non-macOS
    }

    public func completeTask(id: UUID) {
        // No-op on non-macOS
    }

    public func markNeedsAttention(id: UUID, reason: String) {
        // No-op on non-macOS
    }

    public func clearAttention(id: UUID) {
        // No-op on non-macOS
    }

    public func syncFromAgent(taskId: UUID) {
        // No-op on non-macOS
    }

    public func getTask(id: UUID) -> AgentTask? {
        return nil
    }

    public func deleteTask(id: UUID) async {
        // No-op on non-macOS
    }
}
#else
// Fallback for platforms without Observation framework
@MainActor
public final class TaskManager {
    public private(set) var tasks: [UUID: AgentTask] = [:]
    public var agentManager: AgentManager?

    public var activeTasks: [AgentTask] { [] }
    public var tasksNeedingAttention: [AgentTask] { [] }
    public var completedTasks: [AgentTask] { [] }
    public var allTasks: [AgentTask] { [] }

    public init() {}

    public func createTask(from request: TaskCreationRequest) -> AgentTask {
        let task = AgentTask(
            name: request.name,
            status: .pending,
            workspacePath: request.workspacePath,
            gitBranch: request.gitBranch
        )
        return task
    }

    public func startTask(id: UUID) async throws {
        throw AgentManagerError.platformNotSupported
    }

    public func pauseTask(id: UUID) {
        // No-op on non-macOS
    }

    public func resumeTask(id: UUID) async throws {
        throw AgentManagerError.platformNotSupported
    }

    public func cancelTask(id: UUID) async {
        // No-op on non-macOS
    }

    public func completeTask(id: UUID) {
        // No-op on non-macOS
    }

    public func markNeedsAttention(id: UUID, reason: String) {
        // No-op on non-macOS
    }

    public func clearAttention(id: UUID) {
        // No-op on non-macOS
    }

    public func syncFromAgent(taskId: UUID) {
        // No-op on non-macOS
    }

    public func getTask(id: UUID) -> AgentTask? {
        return nil
    }

    public func deleteTask(id: UUID) async {
        // No-op on non-macOS
    }
}
#endif

#endif
