import Foundation
import ACPModel
import ACP
#if canImport(Observation)
import Observation
#endif

/// Errors that can occur during agent management operations
public enum AgentManagerError: Error, Sendable, LocalizedError {
    case agentNotFound(UUID)
    case notConnected
    case noSessionId
    case connectionFailed(String)
    case requestFailed(String)
    case platformNotSupported
    case notAGitRepository
    
    public var errorDescription: String? {
        switch self {
        case .agentNotFound(let id): return "Agent not found: \(id)"
        case .notConnected: return "Not connected to kiro-cli"
        case .noSessionId: return "No active session"
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .requestFailed(let msg): return "Request failed: \(msg)"
        case .platformNotSupported: return "Platform not supported"
        case .notAGitRepository: return "Not a git repository"
        }
    }
}

#if os(macOS)

/// Service that manages multiple concurrent agents
@Observable
@MainActor
public final class AgentManager {
    /// All managed agents indexed by their ID
    public private(set) var agents: [UUID: Agent] = [:]
    
    /// Path to the kiro-cli executable
    public var kirocliPath: String
    
    /// Activity events across all agents
    public private(set) var activityEvents: [ActivityEvent] = []
    
    /// Maximum number of activity events to retain
    private let maxActivityEvents = 100
    
    /// Active ACP connections indexed by agent ID
    private var connections: [UUID: ACPConnection] = [:]
    
    /// Background tasks for prompt responses
    private var promptTasks: [UUID: Task<Void, Never>] = [:]
    
    public init(kirocliPath: String = "/usr/local/bin/kiro-cli") {
        self.kirocliPath = kirocliPath
    }
    
    // MARK: - Activity Event Management
    
    /// Adds an activity event to the stream
    /// - Parameter event: The event to add
    public func addActivityEvent(_ event: ActivityEvent) {
        activityEvents.append(event)
        if activityEvents.count > maxActivityEvents {
            activityEvents.removeFirst()
        }
    }
    
    /// Clears all activity events
    public func clearActivityEvents() {
        activityEvents.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Convert a branch name to a human-readable display name
    /// - Parameter branch: The branch name (e.g., "feature/my-feature")
    /// - Returns: A human-readable name (e.g., "My Feature")
    private func branchNameToDisplayName(_ branch: String) -> String {
        // Remove common prefixes
        var name = branch
        for prefix in ["feature/", "bugfix/", "hotfix/", "release/"] {
            if name.hasPrefix(prefix) {
                name = String(name.dropFirst(prefix.count))
                break
            }
        }
        // Replace separators with spaces and capitalize
        return name
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
    
    /// Start a new agent for a workspace
    /// - Parameters:
    ///   - workspace: The workspace to create an agent for
    ///   - sessionName: Optional custom session name
    /// - Returns: The newly created and connected agent
    public func startAgent(workspace: Workspace, sessionName: String? = nil, agentConfig: String? = nil) async throws -> Agent {
        let agent = Agent(
            name: workspace.name,
            sessionName: sessionName,
            workspace: workspace,
            status: .connecting
        )
        // Publish immediately so sidebar shows the agent
        agents[agent.id] = agent
        
        do {
            print("[ACP] Starting agent for workspace: \(workspace.path.path)")
            print("[ACP] Using kiro-cli at: \(kirocliPath)")
            
            let connection = ACPConnection()
            
            let agentId = agent.id
            let sessionUpdateHandler: @Sendable (SessionUpdate) async -> Void = { [weak self] update in
                await MainActor.run {
                    guard let self = self, let agent = self.agents[agentId] else { return }
                    self.handleSessionUpdate(update, for: agent)
                }
            }
            
            try await connection.connect(
                kirocliPath: kirocliPath,
                agentConfig: agentConfig,
                onSessionUpdate: sessionUpdateHandler
            )
            connections[agent.id] = connection
            print("[ACP] Process spawned and initialized successfully")
            
            print("[ACP] Creating session...")
            let sessionResult = try await connection.createSession(cwd: workspace.path.path)
            print("[ACP] Session created: \(sessionResult.sessionId.value)")
            
            agent.sessionId = sessionResult.sessionId
            agent.messages.append(ChatMessage(role: .system, content: "Agent connected and ready."))
            agent.status = .active
            
            return agent
        } catch {
            print("[ACP] ERROR: \(error)")
            agents.removeValue(forKey: agent.id)
            if let connection = connections.removeValue(forKey: agent.id) {
                await connection.disconnect()
            }
            if isNotLoggedInError(error) {
                throw error
            }
            throw error
        }
    }
    
    /// Load an existing session for an agent
    /// - Parameters:
    ///   - workspace: The workspace for the agent
    ///   - sessionId: The session ID to load
    /// - Returns: The agent with the loaded session
    public func loadAgent(workspace: Workspace, sessionId: String, agentConfig: String? = nil) async throws -> Agent {
        let sessionIdValue = SessionId(value: sessionId)
        let agent = Agent(
            name: workspace.name,
            workspace: workspace,
            sessionId: sessionIdValue,
            status: .connecting
        )
        agents[agent.id] = agent
        
        do {
            let connection = ACPConnection()
            
            let agentId = agent.id
            let sessionUpdateHandler: @Sendable (SessionUpdate) async -> Void = { [weak self] update in
                await MainActor.run {
                    guard let self = self, let agent = self.agents[agentId] else { return }
                    self.handleSessionUpdate(update, for: agent)
                }
            }
            
            try await connection.connect(
                kirocliPath: kirocliPath,
                agentConfig: agentConfig,
                onSessionUpdate: sessionUpdateHandler
            )
            connections[agent.id] = connection
            
            // Proactively remove any stale lock file before attempting to load the session
            let sessionStorage = SessionStorage()
            sessionStorage.removeSessionLockFile(sessionId: sessionId)
            print("[ACP] Proactively cleaned up lock file for session \(sessionId)")
            
            agent.isReplayingSession = true
            _ = try await connection.loadSession(
                sessionId: sessionIdValue,
                cwd: workspace.path.path
            )
            agent.isReplayingSession = false
            
            agent.messages.append(ChatMessage(role: .system, content: "Session resumed."))
            agent.status = .idle
            
            return agent
        } catch {
            agents.removeValue(forKey: agent.id)
            if let connection = connections.removeValue(forKey: agent.id) {
                await connection.disconnect()
            }
            
            // Auth errors should not be retried or recovered
            if isNotLoggedInError(error) {
                throw error
            }
            
            // If the error is a stale session lock, retry session/load before falling back
            if isStaleSessionLockError(error) {
                print("[ACP] Stale session lock detected for session \(sessionId), retrying session/load...")
                
                // Brief delay to allow the lock to release (stale processes killed at app startup)
                try await Task.sleep(nanoseconds: 500_000_000)
                
                // Remove the stale lock file before retrying - this is the critical fix
                let retrySessionStorage = SessionStorage()
                retrySessionStorage.removeSessionLockFile(sessionId: sessionId)
                print("[ACP] Removed stale lock file for session \(sessionId) before retry")
                
                // Retry with a fresh connection but the SAME session ID
                let retryAgent = Agent(
                    name: workspace.name,
                    workspace: workspace,
                    sessionId: sessionIdValue,
                    status: .connecting
                )
                agents[retryAgent.id] = retryAgent

                do {
                    let retryConnection = ACPConnection()
                    
                    let retryAgentId = retryAgent.id
                    let retrySessionUpdateHandler: @Sendable (SessionUpdate) async -> Void = { [weak self] update in
                        await MainActor.run {
                            guard let self = self, let agent = self.agents[retryAgentId] else { return }
                            self.handleSessionUpdate(update, for: agent)
                        }
                    }
                    
                    try await retryConnection.connect(
                        kirocliPath: kirocliPath,
                        agentConfig: agentConfig,
                        onSessionUpdate: retrySessionUpdateHandler
                    )
                    connections[retryAgent.id] = retryConnection
                    
                    retryAgent.isReplayingSession = true
                    _ = try await retryConnection.loadSession(
                        sessionId: sessionIdValue,
                        cwd: workspace.path.path
                    )
                    retryAgent.isReplayingSession = false
                    
                    print("[ACP] Session loaded successfully on retry: \(sessionId)")
                    retryAgent.messages.append(ChatMessage(role: .system, content: "Session resumed."))
                    retryAgent.status = .idle
                    
                    return retryAgent
                } catch {
                    agents.removeValue(forKey: retryAgent.id)
                    if let retryConn = connections.removeValue(forKey: retryAgent.id) {
                        await retryConn.disconnect()
                    }
                    
                    print("[ACP] Retry failed for session \(sessionId), falling back to fresh session...")
                    return try await startFreshAgent(workspace: workspace, agentConfig: agentConfig)
                }
            }
            
            throw error
        }
    }
    
    /// Start a fresh agent with a new session for the given workspace.
    /// Used as a fallback when loading an existing session fails due to stale locks.
    public func startFreshAgent(workspace: Workspace, agentConfig: String? = nil) async throws -> Agent {
        return try await startAgent(workspace: workspace, agentConfig: agentConfig)
    }
    
    /// Checks if an error is a stale session lock error from kiro-cli
    func isStaleSessionLockError(_ error: Error) -> Bool {
        guard let protocolError = error as? ProtocolError else { return false }
        if case .jsonRpcError(_, _, let data) = protocolError,
           let message = data?.stringValue,
           message.contains("Session is active in another process") {
            return true
        }
        return false
    }
    
    /// Checks if an error is a 'not logged in' authentication error
    func isNotLoggedInError(_ error: Error) -> Bool {
        if let acpError = error as? ACPConnectionError,
           case .notLoggedIn = acpError {
            return true
        }
        return false
    }
    /// - Parameter id: The agent ID to stop
    public func stopAgent(id: UUID) async {
        // Cancel prompt task
        promptTasks[id]?.cancel()
        promptTasks.removeValue(forKey: id)
        
        // Disconnect connection
        if let connection = connections[id] {
            await connection.disconnect()
            connections.removeValue(forKey: id)
        }
        
        // Remove agent
        agents.removeValue(forKey: id)
    }
    
    /// Stop all agents gracefully
    public func stopAllAgents() async {
        let agentIds = Array(agents.keys)
        for id in agentIds {
            await stopAgent(id: id)
        }
    }

    /// Synchronously kill all kiro-cli processes (for app quit)
    public func killAllProcesses() {
        for connection in connections.values {
            Task { await connection.killProcess() }
        }
        Thread.sleep(forTimeInterval: 0.1)
    }

    /// Collect PIDs of all running kiro-cli processes
    public func collectProcessPids() async -> [Int32] {
        var pids: [Int32] = []
        for connection in connections.values {
            if let pid = await connection.processId {
                pids.append(pid)
            }
        }
        return pids
    }
    
    /// Get an agent by ID
    /// - Parameter id: The agent ID
    /// - Returns: The agent if found
    public func getAgent(id: UUID) -> Agent? {
        return agents[id]
    }
    
    /// Get all agents
    /// - Returns: Array of all agents
    public func getAllAgents() -> [Agent] {
        return Array(agents.values)
    }
    
    /// Get all agents for a workspace including worktrees
    /// - Parameter workspaceId: The workspace ID to filter by
    /// - Returns: Array of agents in the workspace or its worktrees
    public func getAgentsForWorkspace(_ workspaceId: UUID) -> [Agent] {
        return getAllAgents().filter { agent in
            agent.workspace.id == workspaceId ||
            agent.workspace.sourceWorkspaceId == workspaceId
        }
    }
    
    /// Send a prompt to an agent
    /// - Parameters:
    ///   - agentId: The agent to send the prompt to
    ///   - prompt: The prompt text
    public func sendPrompt(agentId: UUID, prompt: String, imageAttachments: [Data] = []) async throws {
        guard let agent = agents[agentId] else {
            throw AgentManagerError.agentNotFound(agentId)
        }
        
        guard let sessionId = agent.sessionId else {
            throw AgentManagerError.noSessionId
        }
        
        guard let connection = connections[agentId] else {
            throw AgentManagerError.notConnected
        }
        
        // Create user message and append to history
        let userMessage = ChatMessage(
            role: .user,
            content: prompt
        )
        agent.messages.append(userMessage)
        agent.status = .active
        
        // Add activity event for user message
        let messagePreview = prompt.prefix(80)
        addActivityEvent(ActivityEvent(
            agentId: agent.id,
            agentName: agent.name,
            eventType: .message,
            description: "User: \(messagePreview)\(prompt.count > 80 ? "..." : "")"
        ))
        
        // Send prompt and wait for response
        let task = Task { [weak self] in
            do {
                var contentBlocks: [ContentBlock] = [.text(TextContent(text: prompt))]
                for imageData in imageAttachments {
                    let base64String = imageData.base64EncodedString()
                    contentBlocks.append(.image(ImageContent(data: base64String, mimeType: "image/png")))
                }
                let response = try await connection.prompt(sessionId: sessionId, prompt: contentBlocks)
                
                // Handle completion based on stop reason
                await MainActor.run {
                    guard let self = self, let agent = self.agents[agentId] else { return }
                    self.handlePromptCompletion(stopReason: response.stopReason, for: agent)
                }
            } catch {
                await MainActor.run {
                    guard let self = self, let agent = self.agents[agentId] else { return }
                    agent.status = .error
                    agent.errorMessage = error.localizedDescription
                    self.addActivityEvent(ActivityEvent(
                        agentId: agent.id,
                        agentName: agent.name,
                        eventType: .error,
                        description: "Error: \(error.localizedDescription)"
                    ))
                }
            }
        }
        promptTasks[agentId] = task
    }
    
    /// Cancel the current prompt for an agent
    /// - Parameter agentId: The agent ID
    public func cancelPrompt(agentId: UUID) async throws {
        // Send session/cancel to the server if we have a session
        if let agent = agents[agentId],
           let sessionId = agent.sessionId,
           let connection = connections[agentId] {
            try await connection.cancelSession(sessionId: sessionId)
        }
        
        // Cancel the prompt task
        promptTasks[agentId]?.cancel()
        promptTasks.removeValue(forKey: agentId)
    }
    
    /// Start a new agent in a git worktree
    /// - Parameters:
    ///   - sourceWorkspace: The source workspace containing the git repository
    ///   - branchName: The name for the new branch/worktree
    ///   - worktreePath: Optional path for the worktree; if nil, creates next to source workspace
    /// - Returns: The newly created and connected agent
    public func startAgentInWorktree(
        sourceWorkspace: Workspace,
        branchName: String,
        worktreePath: URL? = nil,
        agentConfig: String? = nil
    ) async throws -> Agent {
        // 1. Detect git repository at sourceWorkspace.path
        let gitService = GitService()
        guard let repo = try await gitService.detectGitRepository(at: sourceWorkspace.path) else {
            throw AgentManagerError.notAGitRepository
        }
        
        // 2. Determine worktree path (use provided or generate)
        let targetPath = worktreePath ?? sourceWorkspace.path
            .deletingLastPathComponent()
            .appendingPathComponent("\(sourceWorkspace.name)-\(branchName)")
        
        // 3. Create worktree
        let worktree = try await gitService.createWorktree(
            repository: repo,
            branch: branchName,
            path: targetPath
        )
        
        // 4. Create workspace linked to source
        var newWorkspace = Workspace(
            name: "\(sourceWorkspace.name) (\(branchName))",
            path: worktree.path
        )
        newWorkspace.gitBranch = branchName
        newWorkspace.gitWorktreePath = worktree.path
        newWorkspace.sourceWorkspaceId = sourceWorkspace.id
        
        // 5. Auto-generate session name from branch name
        let sessionName = branchNameToDisplayName(branchName)
        
        // 6. Start agent in new workspace with generated session name
        return try await startAgent(workspace: newWorkspace, sessionName: sessionName, agentConfig: agentConfig)
    }
    
    /// Set the mode for an agent's session
    public func setMode(agentId: UUID, modeId: String) async throws {
        guard let agent = agents[agentId] else {
            throw AgentManagerError.agentNotFound(agentId)
        }
        guard let sessionId = agent.sessionId else {
            throw AgentManagerError.noSessionId
        }
        guard let connection = connections[agentId] else {
            throw AgentManagerError.notConnected
        }
        try await connection.setSessionMode(sessionId: sessionId, modeId: SessionModeId(value: modeId))
    }

    /// Set the model for an agent's session
    public func setModel(agentId: UUID, modelId: String) async throws {
        guard let agent = agents[agentId] else {
            throw AgentManagerError.agentNotFound(agentId)
        }
        guard let sessionId = agent.sessionId else {
            throw AgentManagerError.noSessionId
        }
        guard let connection = connections[agentId] else {
            throw AgentManagerError.notConnected
        }
        try await connection.setSessionModel(sessionId: sessionId, modelId: ModelId(value: modelId))
    }

    /// Execute a slash command for an agent
    public func executeSlashCommand(agentId: UUID, command: String, args: String?) async throws {
        guard let agent = agents[agentId] else {
            throw AgentManagerError.agentNotFound(agentId)
        }
        guard let sessionId = agent.sessionId else {
            throw AgentManagerError.noSessionId
        }
        guard let connection = connections[agentId] else {
            throw AgentManagerError.notConnected
        }
        
        // Show the command as a user message
        agent.messages.append(ChatMessage(role: .user, content: "/\(command)\(args.map { " \($0)" } ?? "")"))
        agent.status = .active
        
        try await connection.executeSlashCommand(sessionId: sessionId, commandName: command, args: args)
    }

    /// Handle a session update for an agent
    /// - Parameters:
    ///   - update: The session update from the SDK
    ///   - agent: The agent to update
    public func handleSessionUpdate(_ update: SessionUpdate, for agent: Agent) {
        // Log every update for debug panel
        let entry: DebugLogEntry
        switch update {
        case .agentMessageChunk(let chunk):
            if case .text(let t) = chunk.content {
                entry = DebugLogEntry(type: "agent_message", summary: t.text.prefix(200).description)
            } else {
                entry = DebugLogEntry(type: "agent_message", summary: "(non-text content)")
            }
            handleAgentMessageChunk(chunk, for: agent)
        case .toolCall(let tc):
            entry = DebugLogEntry(type: "tool_call", summary: "id=\(tc.toolCallId.value) \(tc.title) [\(tc.status?.rawValue ?? "?")]")
            handleToolCall(tc, for: agent)
        case .toolCallUpdate(let tcu):
            entry = DebugLogEntry(type: "tool_call_update", summary: "id=\(tcu.toolCallId.value) status=\(tcu.status?.rawValue ?? "?")")
            handleToolCallUpdate(tcu, for: agent)
        case .agentThoughtChunk(let chunk):
            if case .text(let t) = chunk.content {
                entry = DebugLogEntry(type: "thought", summary: t.text.prefix(200).description)
            } else {
                entry = DebugLogEntry(type: "thought", summary: "(non-text)")
            }
        case .userMessageChunk:
            entry = DebugLogEntry(type: "user_echo", summary: "")
        case .planUpdate:
            entry = DebugLogEntry(type: "plan", summary: "")
        case .availableCommandsUpdate(let c):
            entry = DebugLogEntry(type: "commands", summary: c.availableCommands.map(\.name).joined(separator: ", "))
            agent.availableCommands = c.availableCommands
        case .currentModeUpdate(let m):
            entry = DebugLogEntry(type: "mode_update", summary: m.currentModeId.value)
            agent.currentModeId = m.currentModeId
        case .configOptionUpdate:
            entry = DebugLogEntry(type: "config_update", summary: "")
        case .sessionInfoUpdate(let info):
            entry = DebugLogEntry(type: "session_info", summary: info.title ?? "")
            if let title = info.title {
                agent.sessionTitle = title
            }
        }
        agent.debugLog.append(entry)
    }
    
    // MARK: - Private Session Update Handlers
    
    private func handleAgentMessageChunk(_ chunk: AgentMessageChunk, for agent: Agent) {
        // Discard replay chunks during session loading to prevent duplicating loaded history
        guard !agent.isReplayingSession else { return }
        
        guard case .text(let textContent) = chunk.content else { return }
        let text = textContent.text
        
        // Find or create assistant message
        let lastIndex = agent.messages.count - 1
        if lastIndex >= 0, agent.messages[lastIndex].role == .assistant {
            agent.messages[lastIndex].content += text
        } else {
            agent.messages.append(ChatMessage(role: .assistant, content: text))
        }
    }
    
    private func handleToolCall(_ toolCallUpdate: ToolCallUpdate, for agent: Agent) {
        let id = toolCallUpdate.toolCallId.value
        if let index = agent.activeToolCalls.firstIndex(where: { $0.toolCallId.value == id }),
           index < agent.activeToolCalls.count {
            agent.activeToolCalls[index] = toolCallUpdate
        } else {
            agent.activeToolCalls.append(toolCallUpdate)
            // Only insert a chat marker for genuinely new tool calls
            agent.messages.append(ChatMessage(
                role: .system,
                content: "",
                toolCallIds: [id]
            ))
        }
        agent.toolCallHistory[id] = toolCallUpdate

        addActivityEvent(ActivityEvent(
            agentId: agent.id,
            agentName: agent.name,
            eventType: .toolCall,
            description: "Tool: \(toolCallUpdate.title)"
        ))
    }
    
    private func handleToolCallUpdate(_ updateData: ToolCallUpdateData, for agent: Agent) {
        if let index = agent.activeToolCalls.firstIndex(where: { $0.toolCallId == updateData.toolCallId }),
           index < agent.activeToolCalls.count {
            let existing = agent.activeToolCalls[index]
            
            // Create updated tool call with merged data
            let updated = ToolCallUpdate(
                toolCallId: existing.toolCallId,
                title: updateData.title ?? existing.title,
                kind: updateData.kind ?? existing.kind,
                status: updateData.status ?? existing.status,
                content: updateData.content ?? existing.content,
                locations: updateData.locations ?? existing.locations,
                rawInput: updateData.rawInput ?? existing.rawInput,
                rawOutput: updateData.rawOutput ?? existing.rawOutput
            )
            agent.activeToolCalls[index] = updated
            agent.toolCallHistory[updated.toolCallId.value] = updated
        }
        
        // Extract file changes from diff content
        if let content = updateData.content {
            for item in content {
                if case .diff(let diffContent) = item {
                    let changeType: FileChangeType
                    if diffContent.oldText == nil {
                        changeType = .created
                    } else if diffContent.newText.isEmpty {
                        changeType = .deleted
                    } else {
                        changeType = .modified
                    }
                    
                    let fileChange = FileChange(
                        path: diffContent.path,
                        oldContent: diffContent.oldText,
                        newContent: diffContent.newText,
                        changeType: changeType,
                        toolCallId: updateData.toolCallId.value
                    )
                    agent.fileChanges.append(fileChange)
                }
            }
        }

        // Extract file changes from edit/write tool calls via rawInput
        if updateData.status == .completed,
           let existing = agent.toolCallHistory[updateData.toolCallId.value],
           (existing.kind == .edit || existing.kind == .delete),
           let input = (updateData.rawInput ?? existing.rawInput)?.objectValue,
           let path = input["path"]?.stringValue {
            let alreadyTracked = agent.fileChanges.contains { $0.toolCallId == updateData.toolCallId.value && $0.path == path }
            if !alreadyTracked {
                let changeType: FileChangeType = existing.kind == .delete ? .deleted : .modified
                agent.fileChanges.append(FileChange(
                    path: path,
                    oldContent: input["oldStr"]?.stringValue,
                    newContent: input["newStr"]?.stringValue ?? "",
                    changeType: changeType,
                    toolCallId: updateData.toolCallId.value
                ))
            }
        }
    }
    
    private func handlePromptCompletion(stopReason: StopReason, for agent: Agent) {
        // Clear active tool calls
        agent.activeToolCalls.removeAll()
        
        // Update agent status and add activity event
        switch stopReason {
        case .endTurn, .maxTokens, .maxTurnRequests:
            agent.status = .idle
            addActivityEvent(ActivityEvent(
                agentId: agent.id,
                agentName: agent.name,
                eventType: .complete,
                description: "Task completed"
            ))
        case .cancelled:
            agent.status = .idle
            addActivityEvent(ActivityEvent(
                agentId: agent.id,
                agentName: agent.name,
                eventType: .complete,
                description: "Task cancelled"
            ))
        case .refusal:
            agent.status = .error
            addActivityEvent(ActivityEvent(
                agentId: agent.id,
                agentName: agent.name,
                eventType: .error,
                description: "Agent refused to continue"
            ))
        }
    }
}

#else

// Stub implementation for non-macOS platforms (Linux)
#if canImport(Observation)
@Observable
@MainActor
public final class AgentManager {
    public private(set) var agents: [UUID: Agent] = [:]
    public var kirocliPath: String
    public private(set) var activityEvents: [ActivityEvent] = []
    
    public init(kirocliPath: String = "/usr/local/bin/kiro-cli") {
        self.kirocliPath = kirocliPath
    }
    
    public func addActivityEvent(_ event: ActivityEvent) {
        // No-op on non-macOS
    }
    
    public func clearActivityEvents() {
        // No-op on non-macOS
    }
    
    public func startAgent(workspace: Workspace, sessionName: String? = nil, agentConfig: String? = nil) async throws -> Agent {
        throw AgentManagerError.platformNotSupported
    }
    
    public func loadAgent(workspace: Workspace, sessionId: String, agentConfig: String? = nil) async throws -> Agent {
        throw AgentManagerError.platformNotSupported
    }
    
    public func stopAgent(id: UUID) async {
        // No-op on non-macOS
    }
    
    public func stopAllAgents() async {
        // No-op on non-macOS
    }
    
    public func getAgent(id: UUID) -> Agent? {
        return nil
    }
    
    public func getAllAgents() -> [Agent] {
        return []
    }
    
    public func getAgentsForWorkspace(_ workspaceId: UUID) -> [Agent] {
        return []
    }
    
    public func sendPrompt(agentId: UUID, prompt: String, imageAttachments: [Data] = []) async throws {
        throw AgentManagerError.platformNotSupported
    }
    
    public func cancelPrompt(agentId: UUID) async throws {
        throw AgentManagerError.platformNotSupported
    }
    
    public func executeSlashCommand(agentId: UUID, command: String, args: String?) async throws {
        throw AgentManagerError.platformNotSupported
    }
    
    public func startAgentInWorktree(
        sourceWorkspace: Workspace,
        branchName: String,
        worktreePath: URL? = nil,
        agentConfig: String? = nil
    ) async throws -> Agent {
        throw AgentManagerError.platformNotSupported
    }
    
    public func startFreshAgent(workspace: Workspace, agentConfig: String? = nil) async throws -> Agent {
        throw AgentManagerError.platformNotSupported
    }
    
    public func setMode(agentId: UUID, modeId: String) async throws {
        throw AgentManagerError.platformNotSupported
    }
    
    public func setModel(agentId: UUID, modelId: String) async throws {
        throw AgentManagerError.platformNotSupported
    }
    
    public func handleSessionUpdate(_ update: SessionUpdate, for agent: Agent) {
        // No-op on non-macOS
    }
    
    func isStaleSessionLockError(_ error: Error) -> Bool {
        guard let protocolError = error as? ProtocolError else { return false }
        if case .jsonRpcError(_, _, let data) = protocolError,
           let message = data?.stringValue,
           message.contains("Session is active in another process") {
            return true
        }
        return false
    }
    
    func isNotLoggedInError(_ error: Error) -> Bool {
        if let acpError = error as? ACPConnectionError,
           case .notLoggedIn = acpError {
            return true
        }
        return false
    }
}
#else
// Fallback for platforms without Observation framework
@MainActor
public final class AgentManager {
    public private(set) var agents: [UUID: Agent] = [:]
    public var kirocliPath: String
    public private(set) var activityEvents: [ActivityEvent] = []
    
    public init(kirocliPath: String = "/usr/local/bin/kiro-cli") {
        self.kirocliPath = kirocliPath
    }
    
    public func addActivityEvent(_ event: ActivityEvent) {
        // No-op on non-macOS
    }
    
    public func clearActivityEvents() {
        // No-op on non-macOS
    }
    
    public func startAgent(workspace: Workspace, sessionName: String? = nil, agentConfig: String? = nil) async throws -> Agent {
        throw AgentManagerError.platformNotSupported
    }
    
    public func loadAgent(workspace: Workspace, sessionId: String, agentConfig: String? = nil) async throws -> Agent {
        throw AgentManagerError.platformNotSupported
    }
    
    public func stopAgent(id: UUID) async {
        // No-op on non-macOS
    }
    
    public func stopAllAgents() async {
        // No-op on non-macOS
    }
    
    public func getAgent(id: UUID) -> Agent? {
        return nil
    }
    
    public func getAllAgents() -> [Agent] {
        return []
    }
    
    public func getAgentsForWorkspace(_ workspaceId: UUID) -> [Agent] {
        return []
    }
    
    public func sendPrompt(agentId: UUID, prompt: String, imageAttachments: [Data] = []) async throws {
        throw AgentManagerError.platformNotSupported
    }
    
    public func cancelPrompt(agentId: UUID) async throws {
        throw AgentManagerError.platformNotSupported
    }
    
    public func executeSlashCommand(agentId: UUID, command: String, args: String?) async throws {
        throw AgentManagerError.platformNotSupported
    }
    
    public func startAgentInWorktree(
        sourceWorkspace: Workspace,
        branchName: String,
        worktreePath: URL? = nil,
        agentConfig: String? = nil
    ) async throws -> Agent {
        throw AgentManagerError.platformNotSupported
    }
    
    public func startFreshAgent(workspace: Workspace, agentConfig: String? = nil) async throws -> Agent {
        throw AgentManagerError.platformNotSupported
    }
    
    public func setMode(agentId: UUID, modeId: String) async throws {
        throw AgentManagerError.platformNotSupported
    }
    
    public func setModel(agentId: UUID, modelId: String) async throws {
        throw AgentManagerError.platformNotSupported
    }
    
    public func handleSessionUpdate(_ update: SessionUpdate, for agent: Agent) {
        // No-op on non-macOS
    }
    
    func isStaleSessionLockError(_ error: Error) -> Bool {
        guard let protocolError = error as? ProtocolError else { return false }
        if case .jsonRpcError(_, _, let data) = protocolError,
           let message = data?.stringValue,
           message.contains("Session is active in another process") {
            return true
        }
        return false
    }
    
    func isNotLoggedInError(_ error: Error) -> Bool {
        if let acpError = error as? ACPConnectionError,
           case .notLoggedIn = acpError {
            return true
        }
        return false
    }
}
#endif

#endif
