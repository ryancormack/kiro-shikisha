import Foundation
import ACPModel
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

    /// Reference to app settings for agent configuration lookup
    public var appSettings: AppSettings?

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
            worktreeBranchName: request.worktreeBranchName,
            agentConfigurationId: request.agentConfigurationId
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

        let agentConfigFlag: String? = {
            if let configId = task.agentConfigurationId {
                return appSettings?.agentConfiguration(forId: configId)?.agentFlag
            }
            return nil
        }()

        let agent = try await agentManager.startAgent(workspace: workspace, agentConfig: agentConfigFlag)
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

        // Sync agent state before pausing so messages/fileChanges are preserved
        syncFromAgent(taskId: id)

        // Copy sessionId from agent if the task does not already have one
        if task.sessionId == nil, let agentId = task.agentId,
           let agent = agentManager?.getAgent(id: agentId),
           let sid = agent.sessionId {
            task.sessionId = sid.value
        }

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

        do {
            try await reconnectTask(task: task, sessionId: sessionId)
        } catch {
            task.status = .paused
            task.lastActivityAt = Date()
            persistCurrentState()
            throw error
        }
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
            task.agentConfigurationId = entry.agentConfigurationId
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
        guard agentManager != nil else {
            throw AgentManagerError.platformNotSupported
        }

        let previousStatus = task.status
        task.status = .starting
        task.lastActivityAt = Date()

        do {
            try await reconnectTask(task: task, sessionId: sessionId)
        } catch {
            task.status = previousStatus
            task.lastActivityAt = Date()
            persistCurrentState()
            throw error
        }
    }

    /// Sends a summary prompt to all active tasks, returns the count of tasks prompted
    public func summarizeAllActiveTasks() async -> Int {
        guard let agentManager = agentManager else { return 0 }

        let summaryPrompt = "Please provide a brief summary of what you have been working on most recently, what progress has been made, any blockers or issues encountered, and whether you need any input or decisions from me."

        var promptedCount = 0
        for task in activeTasks {
            guard let agentId = task.agentId else { continue }
            do {
                try await agentManager.sendPrompt(agentId: agentId, prompt: summaryPrompt)
                promptedCount += 1
            } catch {
                print("[TaskManager] Failed to send summary prompt to task '\(task.name)': \(error)")
            }
        }
        return promptedCount
    }

    // MARK: - Private Reconnect Helper

    /// Shared reconnect logic for resumeTask and reopenTask.
    /// Loads session history first to determine the effective session ID,
    /// then loads the agent with that session ID so ACP has the correct context.
    private func reconnectTask(task: AgentTask, sessionId: String) async throws {
        guard let agentManager = agentManager else {
            throw AgentManagerError.platformNotSupported
        }

        let workspace = Workspace(
            name: task.name,
            path: task.workspacePath,
            gitBranch: task.gitBranch
        )

        // Load conversation history FIRST to determine the effective session ID.
        // This fixes the bug where the workspace fallback finds messages from a
        // different session but ACP loads the empty primary session.
        let sessionStorage = SessionStorage()
        var loadedMessages: [ChatMessage] = []
        var effectiveSessionId = sessionId

        print("[TaskReconnect] Loading chat history for session: \(sessionId), workspace: \(task.workspacePath.path)")

        // Try loading from the given session ID first
        do {
            let msgs = try sessionStorage.loadSessionHistory(sessionId: sessionId)
            if !msgs.isEmpty {
                loadedMessages = msgs
                print("[TaskReconnect] Loaded \(msgs.count) messages from primary session \(sessionId)")
            } else {
                print("[TaskReconnect] Session \(sessionId) exists but has no messages")
            }
        } catch {
            print("[TaskReconnect] Failed to load history from session \(sessionId): \(error)")
        }

        // Workspace-based fallback: try other sessions for the same workspace
        if loadedMessages.isEmpty {
            print("[TaskReconnect] Trying workspace-based session fallback for: \(task.workspacePath.path)")
            let result = sessionStorage.loadSessionHistoryWithWorkspaceFallbackResult(
                sessionId: sessionId,
                workspacePath: task.workspacePath
            )
            loadedMessages = result.messages
            if let fallbackId = result.effectiveSessionId {
                effectiveSessionId = fallbackId
                print("[TaskReconnect] Workspace fallback loaded \(loadedMessages.count) messages from session \(fallbackId)")
            }
        }

        // Now load the agent with the effective session ID so ACP has the correct context
        let agentConfigFlag: String? = {
            if let configId = task.agentConfigurationId {
                return appSettings?.agentConfiguration(forId: configId)?.agentFlag
            }
            return nil
        }()

        print("[TaskReconnect] Loading agent with effective session ID: \(effectiveSessionId)")
        do {
            let agent = try await agentManager.loadAgent(workspace: workspace, sessionId: effectiveSessionId, agentConfig: agentConfigFlag)
            task.agentId = agent.id
            task.sessionId = agent.sessionId?.value  // Update sessionId in case a fresh session was created

            if !loadedMessages.isEmpty {
                task.messages = loadedMessages
                // Replace agent.messages entirely with loaded history to prevent
                // duplication from session replay chunks
                agent.messages = loadedMessages
                agent.messages.append(ChatMessage(role: .system, content: "Session resumed."))
                print("[TaskReconnect] Applied \(loadedMessages.count) messages to task and agent")
            } else {
                print("[TaskReconnect] No chat history found for task '\(task.name)'")
            }

            // Restore tool call history from JSONL events for the Terminal tab
            Self.restoreToolCallHistory(from: sessionStorage, sessionId: effectiveSessionId, into: agent)

            // If the session was replaced (fresh session), add a system message
            if agent.sessionId?.value != effectiveSessionId {
                task.messages.append(ChatMessage(role: .system, content: "Session reconnected with a fresh session."))
            }

            task.status = .working
            task.lastActivityAt = Date()
            persistCurrentState()
        } catch {
            if let acpError = error as? ACPConnectionError,
               case .notLoggedIn = acpError {
                task.status = .needsAttention
                task.attentionReason = "Not logged in - please run kiro-cli login"
                task.lastActivityAt = Date()
                persistCurrentState()
            }
            throw error
        }
    }

    // MARK: - Tool Call History Restoration

    /// Known tool names that map to execute kind for the Terminal tab
    private static let executeToolNames: Set<String> = [
        "shell", "bash", "execute_command", "run_command", "terminal"
    ]

    /// Reconstructs tool call history from JSONL session events so the Terminal tab
    /// is populated after app restart.
    static func restoreToolCallHistory(from sessionStorage: SessionStorage, sessionId: String, into agent: Agent) {
        guard let eventsData = sessionStorage.loadSessionEvents(sessionId: sessionId) else { return }

        let decoder = JSONDecoder()
        // Collect tool uses (id -> name, input) and tool results (id -> output text)
        struct ToolUseInfo {
            let name: String
            let input: [String: AnyCodableValue]
        }
        var toolUses: [(id: String, info: ToolUseInfo)] = []
        var toolResults: [String: String] = [:]

        for eventData in eventsData {
            guard let event = try? decoder.decode(SessionEvent.self, from: eventData) else { continue }
            guard let content = event.data.content else { continue }

            for item in content {
                guard let data = item.data, case .object(let dict) = data else { continue }

                if item.kind == "toolUse",
                   let toolUseId = dict["toolUseId"]?.stringValue,
                   let name = dict["name"]?.stringValue {
                    var input: [String: AnyCodableValue] = [:]
                    if case .dict(let inputDict) = dict["input"] ?? .null {
                        input = inputDict
                    }
                    toolUses.append((id: toolUseId, info: ToolUseInfo(name: name, input: input)))
                }

                if item.kind == "toolResult",
                   let toolUseId = dict["toolUseId"]?.stringValue {
                    // Extract text from nested content array
                    if case .array(let resultContent) = dict["content"] ?? .null {
                        let texts = resultContent.compactMap { item -> String? in
                            if case .dict(let d) = item, d["kind"]?.stringValue == "text",
                               let textData = d["data"] {
                                if case .string(let s) = textData { return s }
                            }
                            // Also handle {"type": "text", "text": "..."} format
                            if case .dict(let d) = item, d["type"]?.stringValue == "text",
                               case .string(let s) = d["text"] ?? .null { return s }
                            return nil
                        }
                        if !texts.isEmpty {
                            toolResults[toolUseId] = texts.joined(separator: "\n")
                        }
                    }
                }
            }
        }

        guard !toolUses.isEmpty else { return }

        // Build ToolCallUpdate entries in order
        for (toolUseId, info) in toolUses {
            let kind: ToolKind = executeToolNames.contains(info.name) ? .execute : .other
            let command = info.input["command"]?.stringValue
            let title = command ?? info.name

            // Build rawInput as JsonValue
            var rawInputDict: [String: JsonValue] = [:]
            for (key, val) in info.input {
                rawInputDict[key] = Self.anyCodableToJsonValue(val)
            }
            let rawInput: JsonValue? = rawInputDict.isEmpty ? nil : .object(rawInputDict)

            // Build rawOutput as JsonValue from tool result text
            let rawOutput: JsonValue? = toolResults[toolUseId].map { .string($0) }

            let toolCall = ToolCallUpdate(
                toolCallId: ToolCallId(value: toolUseId),
                title: title,
                kind: kind,
                status: .completed,
                rawInput: rawInput,
                rawOutput: rawOutput
            )
            agent.toolCallHistory[toolUseId] = toolCall
            if !agent.toolCallOrder.contains(toolUseId) {
                agent.toolCallOrder.append(toolUseId)
            }
        }

        let executeCount = toolUses.filter { executeToolNames.contains($0.info.name) }.count
        print("[TaskReconnect] Restored \(toolUses.count) tool calls (\(executeCount) execute) from JSONL")
    }

    private static func anyCodableToJsonValue(_ value: AnyCodableValue) -> JsonValue {
        switch value {
        case .string(let s): return .string(s)
        case .int(let i): return .int(i)
        case .double(let d): return .double(d)
        case .bool(let b): return .bool(b)
        case .null: return .null
        case .array(let arr): return .array(arr.map { anyCodableToJsonValue($0) })
        case .dict(let d): return .object(d.mapValues { anyCodableToJsonValue($0) })
        }
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
    public var appSettings: AppSettings?

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
            worktreeBranchName: request.worktreeBranchName,
            agentConfigurationId: request.agentConfigurationId
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
        syncFromAgent(taskId: id)
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
            task.agentConfigurationId = entry.agentConfigurationId
            tasks[task.id] = task
        }
        persistCurrentState()
    }

    public func summarizeAllActiveTasks() async -> Int {
        return 0
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
    public var appSettings: AppSettings?

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
            worktreeBranchName: request.worktreeBranchName,
            agentConfigurationId: request.agentConfigurationId
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
        syncFromAgent(taskId: id)
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
            task.agentConfigurationId = entry.agentConfigurationId
            tasks[task.id] = task
        }
        persistCurrentState()
    }

    public func summarizeAllActiveTasks() async -> Int {
        return 0
    }

    public func reopenTask(id: UUID) async throws {
        throw AgentManagerError.platformNotSupported
    }
}
#endif

#endif
