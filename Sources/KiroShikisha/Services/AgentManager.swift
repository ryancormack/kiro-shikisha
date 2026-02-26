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
    
    /// Start a new agent for a workspace
    /// - Parameter workspace: The workspace to create an agent for
    /// - Returns: The newly created and connected agent
    public func startAgent(workspace: Workspace) async throws -> Agent {
        let agent = Agent(
            name: workspace.name,
            workspace: workspace,
            status: .connecting
        )
        agents[agent.id] = agent
        
        do {
            print("[ACP] Starting agent for workspace: \(workspace.path.path)")
            print("[ACP] Using kiro-cli at: \(kirocliPath)")
            
            // Create and connect ACP connection
            let connection = ACPConnection()
            
            // Create session update handler that captures agent reference
            let agentId = agent.id
            let sessionUpdateHandler: @Sendable (SessionUpdate) async -> Void = { [weak self] update in
                await MainActor.run {
                    guard let self = self, let agent = self.agents[agentId] else { return }
                    self.handleSessionUpdate(update, for: agent)
                }
            }
            
            try await connection.connect(
                kirocliPath: kirocliPath,
                onSessionUpdate: sessionUpdateHandler
            )
            connections[agent.id] = connection
            print("[ACP] Process spawned and initialized successfully")
            
            // Create new session with workspace path
            print("[ACP] Creating session...")
            let sessionResult = try await connection.createSession(cwd: workspace.path.path)
            print("[ACP] Session created: \(sessionResult.sessionId.value)")
            
            agent.sessionId = sessionResult.sessionId
            agent.status = .active
            
            return agent
        } catch {
            print("[ACP] ERROR: \(error)")
            agent.status = .error
            agent.errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Load an existing session for an agent
    /// - Parameters:
    ///   - workspace: The workspace for the agent
    ///   - sessionId: The session ID to load
    /// - Returns: The agent with the loaded session
    public func loadAgent(workspace: Workspace, sessionId: String) async throws -> Agent {
        let sessionIdValue = SessionId(value: sessionId)
        let agent = Agent(
            name: workspace.name,
            workspace: workspace,
            sessionId: sessionIdValue,
            status: .connecting
        )
        agents[agent.id] = agent
        
        do {
            // Create and connect ACP connection
            let connection = ACPConnection()
            
            // Create session update handler
            let agentId = agent.id
            let sessionUpdateHandler: @Sendable (SessionUpdate) async -> Void = { [weak self] update in
                await MainActor.run {
                    guard let self = self, let agent = self.agents[agentId] else { return }
                    self.handleSessionUpdate(update, for: agent)
                }
            }
            
            try await connection.connect(
                kirocliPath: kirocliPath,
                onSessionUpdate: sessionUpdateHandler
            )
            connections[agent.id] = connection
            
            // Load existing session
            _ = try await connection.loadSession(
                sessionId: sessionIdValue,
                cwd: workspace.path.path
            )
            
            agent.status = .active
            
            return agent
        } catch {
            agent.status = .error
            agent.errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Stop and remove an agent
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
    /// Iterates through all agents and stops each one
    public func stopAllAgents() async {
        let agentIds = Array(agents.keys)
        for id in agentIds {
            await stopAgent(id: id)
        }
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
    
    /// Send a prompt to an agent
    /// - Parameters:
    ///   - agentId: The agent to send the prompt to
    ///   - prompt: The prompt text
    public func sendPrompt(agentId: UUID, prompt: String) async throws {
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
                let contentBlocks = [ContentBlock.text(TextContent(text: prompt))]
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
        // Cancel the prompt task
        promptTasks[agentId]?.cancel()
        promptTasks.removeValue(forKey: agentId)
        
        // Note: The SDK's ClientConnection doesn't expose a cancel method directly
        // We could add support for session/cancel if needed
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
        worktreePath: URL? = nil
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
        
        // 5. Start agent in new workspace
        return try await startAgent(workspace: newWorkspace)
    }
    
    /// Handle a session update for an agent
    /// - Parameters:
    ///   - update: The session update from the SDK
    ///   - agent: The agent to update
    public func handleSessionUpdate(_ update: SessionUpdate, for agent: Agent) {
        switch update {
        case .agentMessageChunk(let chunk):
            handleAgentMessageChunk(chunk, for: agent)
            
        case .toolCall(let toolCallUpdate):
            handleToolCall(toolCallUpdate, for: agent)
            
        case .toolCallUpdate(let toolCallUpdateData):
            handleToolCallUpdate(toolCallUpdateData, for: agent)
            
        case .userMessageChunk:
            // Echo of user message, ignore
            break
            
        case .agentThoughtChunk:
            // Internal reasoning, could log or display separately
            break
            
        case .planUpdate:
            // Execution plan, could display if desired
            break
            
        case .availableCommandsUpdate(let commandsUpdate):
            let commandNames = commandsUpdate.availableCommands.map { $0.name }.joined(separator: ", ")
            print("[ACP] Available commands: \(commandNames)")
            
        case .currentModeUpdate:
            // Mode change, could track if desired
            break
            
        case .configOptionUpdate:
            // Config options updated
            break
            
        case .sessionInfoUpdate:
            // Session info updated
            break
        }
    }
    
    // MARK: - Private Session Update Handlers
    
    private func handleAgentMessageChunk(_ chunk: AgentMessageChunk, for agent: Agent) {
        // Get text content from chunk
        guard case .text(let textContent) = chunk.content else { return }
        let text = textContent.text
        
        // Find or create assistant message
        if let lastMessage = agent.messages.last, lastMessage.role == .assistant {
            // Append to existing assistant message
            let index = agent.messages.count - 1
            agent.messages[index].content += text
        } else {
            // Create new assistant message
            let message = ChatMessage(
                role: .assistant,
                content: text
            )
            agent.messages.append(message)
        }
    }
    
    private func handleToolCall(_ toolCallUpdate: ToolCallUpdate, for agent: Agent) {
        // Add to active tool calls
        agent.activeToolCalls.append(toolCallUpdate)
        
        // Associate with current assistant message
        if let lastMessage = agent.messages.last, lastMessage.role == .assistant {
            let index = agent.messages.count - 1
            var toolCallIds = agent.messages[index].toolCallIds ?? []
            toolCallIds.append(toolCallUpdate.toolCallId.value)
            agent.messages[index].toolCallIds = toolCallIds
        }
        
        // Add activity event for tool call
        addActivityEvent(ActivityEvent(
            agentId: agent.id,
            agentName: agent.name,
            eventType: .toolCall,
            description: "Tool: \(toolCallUpdate.title)"
        ))
    }
    
    private func handleToolCallUpdate(_ updateData: ToolCallUpdateData, for agent: Agent) {
        // Find and update the existing tool call
        if let index = agent.activeToolCalls.firstIndex(where: { $0.toolCallId == updateData.toolCallId }) {
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
    
    public func startAgent(workspace: Workspace) async throws -> Agent {
        throw AgentManagerError.platformNotSupported
    }
    
    public func loadAgent(workspace: Workspace, sessionId: String) async throws -> Agent {
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
    
    public func sendPrompt(agentId: UUID, prompt: String) async throws {
        throw AgentManagerError.platformNotSupported
    }
    
    public func cancelPrompt(agentId: UUID) async throws {
        throw AgentManagerError.platformNotSupported
    }
    
    public func startAgentInWorktree(
        sourceWorkspace: Workspace,
        branchName: String,
        worktreePath: URL? = nil
    ) async throws -> Agent {
        throw AgentManagerError.platformNotSupported
    }
    
    public func handleSessionUpdate(_ update: SessionUpdate, for agent: Agent) {
        // No-op on non-macOS
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
    
    public func startAgent(workspace: Workspace) async throws -> Agent {
        throw AgentManagerError.platformNotSupported
    }
    
    public func loadAgent(workspace: Workspace, sessionId: String) async throws -> Agent {
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
    
    public func sendPrompt(agentId: UUID, prompt: String) async throws {
        throw AgentManagerError.platformNotSupported
    }
    
    public func cancelPrompt(agentId: UUID) async throws {
        throw AgentManagerError.platformNotSupported
    }
    
    public func startAgentInWorktree(
        sourceWorkspace: Workspace,
        branchName: String,
        worktreePath: URL? = nil
    ) async throws -> Agent {
        throw AgentManagerError.platformNotSupported
    }
    
    public func handleSessionUpdate(_ update: SessionUpdate, for agent: Agent) {
        // No-op on non-macOS
    }
}
#endif

#endif
