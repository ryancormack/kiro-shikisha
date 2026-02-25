import Foundation
#if canImport(Observation)
import Observation
#endif

/// Errors that can occur during agent management operations
public enum AgentManagerError: Error, Sendable {
    case agentNotFound(UUID)
    case notConnected
    case noSessionId
    case connectionFailed(String)
    case requestFailed(JSONRPCError)
    case platformNotSupported
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
    
    /// Active ACP connections indexed by agent ID
    private var connections: [UUID: ACPConnection] = [:]
    
    /// Request ID counter for JSON-RPC
    private var nextRequestId: Int = 1
    
    /// Pending response handlers indexed by request ID
    private var pendingRequests: [Int: CheckedContinuation<Data, Error>] = [:]
    
    /// Background tasks for streaming updates
    private var streamingTasks: [UUID: Task<Void, Never>] = [:]
    
    public init(kirocliPath: String = "/usr/local/bin/kiro-cli") {
        self.kirocliPath = kirocliPath
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
            // Create and connect ACP connection
            let connection = ACPConnection()
            try await connection.connect(kirocliPath: kirocliPath)
            connections[agent.id] = connection
            
            // Start streaming task for this connection
            startStreamingTask(for: agent, connection: connection)
            
            // Send initialize request
            let initializeResult = try await sendInitialize(agentId: agent.id)
            
            // Create new session with workspace path
            let sessionResult = try await sendSessionNew(
                agentId: agent.id,
                cwd: workspace.path.path
            )
            
            agent.sessionId = sessionResult.sessionId
            agent.status = .active
            
            return agent
        } catch {
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
        let agent = Agent(
            name: workspace.name,
            workspace: workspace,
            sessionId: sessionId,
            status: .connecting
        )
        agents[agent.id] = agent
        
        do {
            // Create and connect ACP connection
            let connection = ACPConnection()
            try await connection.connect(kirocliPath: kirocliPath)
            connections[agent.id] = connection
            
            // Start streaming task for this connection
            startStreamingTask(for: agent, connection: connection)
            
            // Send initialize request
            _ = try await sendInitialize(agentId: agent.id)
            
            // Load existing session
            try await sendSessionLoad(
                agentId: agent.id,
                sessionId: sessionId,
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
        // Cancel streaming task
        streamingTasks[id]?.cancel()
        streamingTasks.removeValue(forKey: id)
        
        // Disconnect connection
        if let connection = connections[id] {
            await connection.disconnect()
            connections.removeValue(forKey: id)
        }
        
        // Remove agent
        agents.removeValue(forKey: id)
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
        
        guard connections[agentId] != nil else {
            throw AgentManagerError.notConnected
        }
        
        // Create user message and append to history
        let userMessage = ChatMessage(
            role: .user,
            content: prompt
        )
        agent.messages.append(userMessage)
        agent.status = .active
        
        // Send prompt request (response comes via streaming)
        try await sendSessionPrompt(
            agentId: agentId,
            sessionId: sessionId,
            content: [.text(prompt)]
        )
    }
    
    /// Cancel the current prompt for an agent
    /// - Parameter agentId: The agent ID
    public func cancelPrompt(agentId: UUID) async throws {
        guard let agent = agents[agentId] else {
            throw AgentManagerError.agentNotFound(agentId)
        }
        
        guard let sessionId = agent.sessionId else {
            throw AgentManagerError.noSessionId
        }
        
        guard connections[agentId] != nil else {
            throw AgentManagerError.notConnected
        }
        
        try await sendSessionCancel(agentId: agentId, sessionId: sessionId)
    }
    
    /// Handle a session update for an agent
    /// - Parameters:
    ///   - update: The session update
    ///   - agent: The agent to update
    public func handleSessionUpdate(_ update: SessionUpdate, for agent: Agent) {
        switch update {
        case .agentMessageChunk(let chunk):
            handleAgentMessageChunk(chunk, for: agent)
            
        case .toolCall(let toolCall):
            handleToolCall(toolCall, for: agent)
            
        case .toolCallUpdate(let toolCallUpdate):
            handleToolCallUpdate(toolCallUpdate, for: agent)
            
        case .turnEnd(let turnEnd):
            handleTurnEnd(turnEnd, for: agent)
        }
    }
    
    // MARK: - Private ACP Communication Methods
    
    private func sendInitialize(agentId: UUID) async throws -> InitializeResult {
        let params = InitializeParams(
            protocolVersion: "1.0",
            clientInfo: ClientInfo(name: "KiroShikisha", version: "1.0.0"),
            clientCapabilities: ClientCapabilities(
                fs: FileSystemCapabilities(readTextFile: true, writeTextFile: true),
                terminal: TerminalCapabilities(execute: true)
            )
        )
        
        return try await sendRequest(
            agentId: agentId,
            method: "initialize",
            params: params
        )
    }
    
    private func sendSessionNew(agentId: UUID, cwd: String) async throws -> SessionNewResult {
        let params = SessionNewParams(cwd: cwd)
        return try await sendRequest(
            agentId: agentId,
            method: "session/new",
            params: params
        )
    }
    
    private func sendSessionLoad(agentId: UUID, sessionId: String, cwd: String) async throws {
        let params = SessionLoadParams(sessionId: sessionId, cwd: cwd)
        let _: JSONValue = try await sendRequest(
            agentId: agentId,
            method: "session/load",
            params: params
        )
    }
    
    private func sendSessionPrompt(agentId: UUID, sessionId: String, content: [ContentBlock]) async throws {
        let params = SessionPromptParams(sessionId: sessionId, content: content)
        let _: JSONValue = try await sendRequest(
            agentId: agentId,
            method: "session/prompt",
            params: params
        )
    }
    
    private func sendSessionCancel(agentId: UUID, sessionId: String) async throws {
        let params = SessionCancelParams(sessionId: sessionId)
        let _: JSONValue = try await sendRequest(
            agentId: agentId,
            method: "session/cancel",
            params: params
        )
    }
    
    private func sendRequest<Params: Codable & Sendable, Result: Codable & Sendable>(
        agentId: UUID,
        method: String,
        params: Params
    ) async throws -> Result {
        guard let connection = connections[agentId] else {
            throw AgentManagerError.notConnected
        }
        
        let requestId = nextRequestId
        nextRequestId += 1
        
        let request = JSONRPCRequest(id: requestId, method: method, params: params)
        try await connection.send(request)
        
        // Wait for response via continuation
        let responseData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            pendingRequests[requestId] = continuation
        }
        
        // Decode response
        let decoder = JSONDecoder()
        let response = try decoder.decode(JSONRPCResponse<Result>.self, from: responseData)
        
        if let error = response.error {
            throw AgentManagerError.requestFailed(error)
        }
        
        guard let result = response.result else {
            throw AgentManagerError.requestFailed(JSONRPCError(
                code: JSONRPCError.internalError,
                message: "No result in response"
            ))
        }
        
        return result
    }
    
    // MARK: - Private Streaming Methods
    
    private func startStreamingTask(for agent: Agent, connection: ACPConnection) {
        let task = Task { [weak self] in
            await self?.handleStream(for: agent, connection: connection)
        }
        streamingTasks[agent.id] = task
    }
    
    private func handleStream(for agent: Agent, connection: ACPConnection) async {
        let stream = await connection.receive()
        let decoder = JSONDecoder()
        
        do {
            for try await data in stream {
                await processMessage(data, for: agent, decoder: decoder)
            }
        } catch {
            await MainActor.run {
                agent.status = .error
                agent.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func processMessage(_ data: Data, for agent: Agent, decoder: JSONDecoder) async {
        // Try to decode as a response (has "id" field)
        if let responseId = extractResponseId(from: data) {
            // This is a response to a pending request
            if let continuation = pendingRequests.removeValue(forKey: responseId) {
                continuation.resume(returning: data)
            }
            return
        }
        
        // Try to decode as a notification (no "id" field)
        if let notification = try? decoder.decode(
            JSONRPCNotification<SessionUpdateNotification>.self,
            from: data
        ) {
            if let params = notification.params {
                await MainActor.run {
                    self.handleSessionUpdate(params.update, for: agent)
                }
            }
        }
    }
    
    private func extractResponseId(from data: Data) -> Int? {
        // Quick JSON parsing to extract id field
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? Int else {
            return nil
        }
        return id
    }
    
    // MARK: - Private Session Update Handlers
    
    private func handleAgentMessageChunk(_ chunk: AgentMessageChunk, for agent: Agent) {
        // Get text content from chunk
        guard let text = chunk.content.text else { return }
        
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
    
    private func handleToolCall(_ toolCall: ToolCall, for agent: Agent) {
        // Add to active tool calls
        agent.activeToolCalls.append(toolCall)
        
        // Associate with current assistant message
        if let lastMessage = agent.messages.last, lastMessage.role == .assistant {
            let index = agent.messages.count - 1
            var toolCallIds = agent.messages[index].toolCallIds ?? []
            toolCallIds.append(toolCall.toolCallId)
            agent.messages[index].toolCallIds = toolCallIds
        }
    }
    
    private func handleToolCallUpdate(_ update: ToolCallUpdate, for agent: Agent) {
        // Find and update the existing tool call
        if let index = agent.activeToolCalls.firstIndex(where: { $0.toolCallId == update.toolCallId }) {
            let existingCall = agent.activeToolCalls[index]
            let updatedCall = ToolCall(
                toolCallId: existingCall.toolCallId,
                title: existingCall.title,
                kind: existingCall.kind,
                status: update.status,
                content: update.content ?? existingCall.content,
                rawInput: existingCall.rawInput,
                rawOutput: existingCall.rawOutput
            )
            agent.activeToolCalls[index] = updatedCall
        }
        
        // Extract file changes from diff content
        if let toolContent = update.toolContent {
            switch toolContent {
            case .diff(let diffContent):
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
                    toolCallId: update.toolCallId
                )
                agent.fileChanges.append(fileChange)
                
            case .content, .terminal:
                // These content types don't represent file changes
                break
            }
        }
    }
    
    private func handleTurnEnd(_ turnEnd: TurnEnd, for agent: Agent) {
        // Clear active tool calls
        agent.activeToolCalls.removeAll()
        
        // Update agent status
        switch turnEnd.reason {
        case .endTurn, .maxTurns:
            agent.status = .idle
        case .cancelled:
            agent.status = .idle
        case .error:
            agent.status = .error
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
    
    public init(kirocliPath: String = "/usr/local/bin/kiro-cli") {
        self.kirocliPath = kirocliPath
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
    
    public init(kirocliPath: String = "/usr/local/bin/kiro-cli") {
        self.kirocliPath = kirocliPath
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
    
    public func handleSessionUpdate(_ update: SessionUpdate, for agent: Agent) {
        // No-op on non-macOS
    }
}
#endif

#endif
