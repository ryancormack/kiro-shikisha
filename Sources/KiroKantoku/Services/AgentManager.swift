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
    
    /// Pending permission completion handlers indexed by agent ID
    private var permissionHandlers: [UUID: @Sendable (RequestPermissionOutcome) -> Void] = [:]
    
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
    
    /// Build a permission request handler for a given agent ID
    private func makePermissionRequestHandler(agentId: UUID) -> @Sendable (ToolCallUpdateData, [PermissionOption], @escaping @Sendable (RequestPermissionOutcome) -> Void) -> Void {
        return { [weak self] toolCall, options, completion in
            Task { @MainActor in
                guard let self = self, let agent = self.agents[agentId] else {
                    completion(.cancelled)
                    return
                }
                
                // Extract display information from the tool call
                let title = toolCall.title ?? "Tool Call"
                let kind = toolCall.kind?.rawValue
                var rawInputStr: String? = nil
                if let rawInput = toolCall.rawInput {
                    // Try to extract just the command if it is a shell/execute call
                    if let obj = rawInput.objectValue, let cmd = obj["command"]?.stringValue {
                        rawInputStr = cmd
                    } else if let data = try? JSONEncoder().encode(rawInput),
                              let jsonStr = String(data: data, encoding: .utf8) {
                        rawInputStr = jsonStr
                    }
                }
                
                let displayOptions = options.map { opt in
                    PermissionOptionDisplay(
                        optionId: opt.optionId.value,
                        label: opt.name,
                        kind: opt.kind.rawValue
                    )
                }
                
                agent.pendingPermissionRequest = PendingPermissionRequest(
                    toolCallTitle: title,
                    toolCallKind: kind,
                    rawInput: rawInputStr,
                    options: displayOptions
                )
                
                self.permissionHandlers[agentId] = completion
                
                agent.debugLog.append(DebugLogEntry(
                    type: "permission_request",
                    summary: "Permission requested for: \(title)"
                ))
            }
        }
    }
    
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
            
            let kiroNotificationHandler: @Sendable (String, JsonValue?) async -> Void = { [weak self] method, params in
                await MainActor.run {
                    guard let self = self, let agent = self.agents[agentId] else { return }
                    self.handleKiroNotification(method: method, params: params, for: agent)
                }
            }
            
            let permissionRequestHandler = makePermissionRequestHandler(agentId: agentId)
            
            try await connection.connect(
                kirocliPath: kirocliPath,
                agentConfig: agentConfig,
                onSessionUpdate: sessionUpdateHandler,
                onKiroNotification: kiroNotificationHandler,
                onPermissionRequest: permissionRequestHandler
            )
            connections[agent.id] = connection
            print("[ACP] Process spawned and initialized successfully")
            
            print("[ACP] Creating session...")
            let sessionResult = try await connection.createSession(cwd: workspace.path.path)
            print("[ACP] Session created: \(sessionResult.sessionId.value)")
            
            agent.sessionId = sessionResult.sessionId
            if let configOptions = sessionResult.configOptions {
                agent.configOptions = configOptions
            }
            if let modes = sessionResult.modes {
                agent.availableModes = modes.availableModes
                agent.currentModeId = modes.currentModeId
            }
            if let models = sessionResult.models {
                agent.availableModels = models.availableModels
                agent.currentModelId = models.currentModelId
            }
            agent.messages.append(ChatMessage(role: .system, content: "Agent connected and ready."))
            agent.status = .active
            
            let skillDiscovery = SkillDiscoveryService()
            agent.availableSkills = skillDiscovery.discoverSkills(workspacePath: workspace.path)
            
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
            
            let kiroNotificationHandler: @Sendable (String, JsonValue?) async -> Void = { [weak self] method, params in
                await MainActor.run {
                    guard let self = self, let agent = self.agents[agentId] else { return }
                    self.handleKiroNotification(method: method, params: params, for: agent)
                }
            }
            
            let permissionRequestHandler = makePermissionRequestHandler(agentId: agentId)
            
            try await connection.connect(
                kirocliPath: kirocliPath,
                agentConfig: agentConfig,
                onSessionUpdate: sessionUpdateHandler,
                onKiroNotification: kiroNotificationHandler,
                onPermissionRequest: permissionRequestHandler
            )
            connections[agent.id] = connection
            
            // Proactively remove any stale lock file before attempting to load the session
            let sessionStorage = SessionStorage()
            sessionStorage.removeSessionLockFile(sessionId: sessionId)
            print("[ACP] Proactively cleaned up lock file for session \(sessionId)")
            
            agent.isReplayingSession = true
            let loadResult = try await connection.loadSession(
                sessionId: sessionIdValue,
                cwd: workspace.path.path
            )
            agent.isReplayingSession = false
            
            if let configOptions = loadResult.configOptions {
                agent.configOptions = configOptions
            }
            if let modes = loadResult.modes {
                agent.availableModes = modes.availableModes
                agent.currentModeId = modes.currentModeId
                print("[ACP] loadSession: set \(modes.availableModes.count) modes, currentModeId=\(modes.currentModeId)")
            } else {
                print("[ACP] loadSession: modes is nil")
            }
            if let models = loadResult.models {
                agent.availableModels = models.availableModels
                agent.currentModelId = models.currentModelId
                print("[ACP] loadSession: set \(models.availableModels.count) models, currentModelId=\(models.currentModelId)")
            } else {
                print("[ACP] loadSession: models is nil")
            }
            agent.messages.append(ChatMessage(role: .system, content: "Session resumed."))
            agent.status = .idle
            
            let skillDiscovery = SkillDiscoveryService()
            agent.availableSkills = skillDiscovery.discoverSkills(workspacePath: workspace.path)
            
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
                    
                    let retryKiroNotificationHandler: @Sendable (String, JsonValue?) async -> Void = { [weak self] method, params in
                        await MainActor.run {
                            guard let self = self, let agent = self.agents[retryAgentId] else { return }
                            self.handleKiroNotification(method: method, params: params, for: agent)
                        }
                    }
                    
                    let retryPermissionRequestHandler = makePermissionRequestHandler(agentId: retryAgentId)
                    
                    try await retryConnection.connect(
                        kirocliPath: kirocliPath,
                        agentConfig: agentConfig,
                        onSessionUpdate: retrySessionUpdateHandler,
                        onKiroNotification: retryKiroNotificationHandler,
                        onPermissionRequest: retryPermissionRequestHandler
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
        agent.currentModeId = SessionModeId(value: modeId)
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
        agent.currentModelId = ModelId(value: modelId)
    }

    /// Set a configuration option for an agent's session
    public func setConfigOption(agentId: UUID, configId: String, value: String) async throws {
        guard let agent = agents[agentId] else {
            throw AgentManagerError.agentNotFound(agentId)
        }
        guard let sessionId = agent.sessionId else {
            throw AgentManagerError.noSessionId
        }
        guard let connection = connections[agentId] else {
            throw AgentManagerError.notConnected
        }
        try await connection.setSessionConfigOption(sessionId: sessionId, configId: SessionConfigId(value: configId), value: SessionConfigValueId(value: value))
    }

    /// Execute a slash command for an agent.
    /// Returns the response message from the server, if any.
    @discardableResult
    public func executeSlashCommand(agentId: UUID, command: String, args: [String: String] = [:]) async throws -> String? {
        guard let agent = agents[agentId] else {
            throw AgentManagerError.agentNotFound(agentId)
        }
        guard let sessionId = agent.sessionId else {
            throw AgentManagerError.noSessionId
        }
        guard let connection = connections[agentId] else {
            throw AgentManagerError.notConnected
        }
        
        print("[ACP] AgentManager.executeSlashCommand: command=\(command) agentId=\(agentId) sessionId=\(sessionId.value)")
        
        // Show the command as a user message
        let argsDisplay = args.isEmpty ? "" : " " + args.values.joined(separator: " ")
        agent.messages.append(ChatMessage(role: .user, content: "/\(command)\(argsDisplay)"))
        agent.status = .active
        
        // Send command in a background task so the UI stays responsive.
        // The actual command output arrives via session updates (agent message chunks).
        // executeSlashCommand awaits the JSON-RPC acknowledgment response.
        let task = Task { [weak self] in
            do {
                print("[ACP] AgentManager.executeSlashCommand: background task started for command=\(command)")
                let responseMessage = try await connection.executeSlashCommand(sessionId: sessionId, commandName: command, args: args)
                print("[ACP] AgentManager.executeSlashCommand: background task completed for command=\(command)")
                await MainActor.run {
                    guard let self = self, let agent = self.agents[agentId] else { return }
                    if let message = responseMessage, !message.isEmpty {
                        agent.messages.append(ChatMessage(role: .assistant, content: message))
                    }
                    agent.status = .idle
                }
            } catch {
                print("[ACP] AgentManager.executeSlashCommand: background task error for command=\(command): \(error)")
                await MainActor.run {
                    guard let self = self, let agent = self.agents[agentId] else { return }
                    agent.status = .error
                    agent.errorMessage = error.localizedDescription
                    agent.debugLog.append(DebugLogEntry(
                        type: "slash_command_error",
                        summary: "Slash command /\(command) failed: \(error.localizedDescription)"
                    ))
                }
            }
        }
        promptTasks[agentId] = task
        return nil
    }

    /// Request available options for a selection-type slash command
    public func requestCommandOptions(agentId: UUID, command: String, partial: String = "") async throws -> [CommandOption] {
        guard let agent = agents[agentId] else {
            throw AgentManagerError.agentNotFound(agentId)
        }
        guard let sessionId = agent.sessionId else {
            throw AgentManagerError.noSessionId
        }
        guard let connection = connections[agentId] else {
            throw AgentManagerError.notConnected
        }

        return try await connection.requestCommandOptions(sessionId: sessionId, command: command, partial: partial)
    }

    /// Resolve a pending permission request with the user's selection
    /// - Parameters:
    ///   - agentId: The agent ID
    ///   - optionId: The selected option ID
    public func resolvePermission(agentId: UUID, optionId: String) {
        guard let agent = agents[agentId] else { return }
        agent.pendingPermissionRequest = nil
        
        if let handler = permissionHandlers.removeValue(forKey: agentId) {
            handler(.selected(PermissionOptionId(value: optionId)))
        }
        
        agent.debugLog.append(DebugLogEntry(
            type: "permission_response",
            summary: "User selected: \(optionId)"
        ))
    }
    
    /// Cancel a pending permission request
    /// - Parameter agentId: The agent ID
    public func cancelPermission(agentId: UUID) {
        guard let agent = agents[agentId] else { return }
        agent.pendingPermissionRequest = nil
        
        if let handler = permissionHandlers.removeValue(forKey: agentId) {
            handler(.cancelled)
        }
        
        agent.debugLog.append(DebugLogEntry(
            type: "permission_response",
            summary: "Permission cancelled"
        ))
    }

    /// Handle a Kiro vendor extension notification
    func handleKiroNotification(method: String, params: JsonValue?, for agent: Agent) {
        // Encode raw params to JSON string for debug logging
        let rawJson: String?
        if let params = params,
           let jsonData = try? JSONEncoder().encode(params) {
            rawJson = String(data: jsonData, encoding: .utf8)
        } else {
            rawJson = nil
        }
        
        switch method {
        case "_kiro.dev/commands/available":
            if let params = params {
                do {
                    let data = try JSONEncoder().encode(params)
                    let parsed = try JSONDecoder().decode(KiroCommandsAvailableParams.self, from: data)
                    agent.kiroAvailableCommands = parsed.commands
                } catch {
                    print("[Kiro] Failed to decode commands/available: \(error). Attempting fallback.")
                    // Fallback: manually extract commands from the raw JsonValue
                    if let obj = params.objectValue,
                       let commandsArray = obj["commands"]?.arrayValue {
                        var commands: [KiroAvailableCommand] = []
                        for item in commandsArray {
                            if let cmdObj = item.objectValue,
                               let name = cmdObj["name"]?.stringValue,
                               let description = cmdObj["description"]?.stringValue {
                                let meta = cmdObj["meta"]
                                commands.append(KiroAvailableCommand(name: name, description: description, meta: meta))
                            }
                        }
                        if !commands.isEmpty {
                            agent.kiroAvailableCommands = commands
                            print("[Kiro] Fallback decoded \(commands.count) commands")
                        }
                    }
                }
            }
            agent.debugLog.append(DebugLogEntry(
                type: "kiro_commands_available",
                summary: "Commands available: \(agent.kiroAvailableCommands.map(\.name).joined(separator: ", "))",
                rawJson: rawJson
            ))
            
        case "_kiro.dev/metadata":
            if let params = params {
                if let data = try? JSONEncoder().encode(params),
                   let parsed = try? JSONDecoder().decode(KiroMetadataParams.self, from: data) {
                    agent.contextUsagePercentage = parsed.contextUsagePercentage
                }
            }
            agent.debugLog.append(DebugLogEntry(
                type: "kiro_metadata",
                summary: "Context usage: \(agent.contextUsagePercentage.map { String(format: "%.1f%%", $0) } ?? "unknown")",
                rawJson: rawJson
            ))
            
        case "_kiro.dev/agent/switched":
            if let params = params {
                if let data = try? JSONEncoder().encode(params),
                   let parsed = try? JSONDecoder().decode(KiroAgentSwitchedParams.self, from: data) {
                    agent.name = parsed.agentName
                    agent.messages.append(ChatMessage(
                        role: .system,
                        content: "Agent switched from \(parsed.previousAgentName) to \(parsed.agentName)"
                    ))
                    if let welcomeMessage = parsed.welcomeMessage {
                        agent.messages.append(ChatMessage(
                            role: .system,
                            content: welcomeMessage
                        ))
                    }
                }
            }
            agent.debugLog.append(DebugLogEntry(
                type: "kiro_agent_switched",
                summary: "Agent switched to \(agent.name)",
                rawJson: rawJson
            ))
            
        case "_kiro.dev/session/update":
            if let params = params {
                if let data = try? JSONEncoder().encode(params) {
                    // Try tool_call_chunk
                    if let parsed = try? JSONDecoder().decode(KiroToolCallChunkUpdate.self, from: data),
                       parsed.sessionUpdate == "tool_call_chunk" {
                        print("[Kiro] Tool call chunk: \(parsed.toolCallId) - \(parsed.title)")
                    }
                    // Try plan update
                    else if let parsed = try? JSONDecoder().decode(KiroPlanUpdate.self, from: data),
                            parsed.sessionUpdate == "plan" {
                        let entries = parsed.steps.map { step in
                            let status: PlanEntryStatus
                            switch step.status {
                            case "completed": status = .completed
                            case "in_progress": status = .inProgress
                            default: status = .pending
                            }
                            return PlanEntry(content: step.description, priority: .medium, status: status)
                        }
                        agent.currentPlan = PlanUpdate(entries: entries)
                        print("[Kiro] Plan update: \(entries.count) steps")
                    }
                    // Try agent_thought_chunk
                    else if let parsed = try? JSONDecoder().decode(KiroAgentThoughtChunkUpdate.self, from: data),
                            parsed.sessionUpdate == "agent_thought_chunk" {
                        if !agent.isReplayingSession {
                            agent.thoughtContent += parsed.content.text
                        }
                        print("[Kiro] Thought chunk: \(parsed.content.text.prefix(100))")
                    }
                }
            }
            agent.debugLog.append(DebugLogEntry(
                type: "kiro_session_update",
                summary: "Kiro session update received",
                rawJson: rawJson
            ))
            
        case "_kiro.dev/compaction/status":
            if let params = params {
                if let data = try? JSONEncoder().encode(params),
                   let parsed = try? JSONDecoder().decode(KiroCompactionStatusParams.self, from: data) {
                    agent.isCompacting = true
                    agent.compactionMessage = parsed.message
                }
            }
            agent.debugLog.append(DebugLogEntry(
                type: "kiro_compaction_status",
                summary: "Compaction: \(agent.compactionMessage ?? "unknown")",
                rawJson: rawJson
            ))
            
        case "_kiro.dev/clear/status":
            if let params = params {
                if let data = try? JSONEncoder().encode(params),
                   let parsed = try? JSONDecoder().decode(KiroClearStatusParams.self, from: data) {
                    agent.isClearingHistory = true
                    agent.clearStatusMessage = parsed.message
                }
            }
            agent.debugLog.append(DebugLogEntry(
                type: "kiro_clear_status",
                summary: "Clear: \(agent.clearStatusMessage ?? "unknown")",
                rawJson: rawJson
            ))
            
        case "_kiro.dev/mcp/oauth_request":
            if let params = params {
                if let data = try? JSONEncoder().encode(params),
                   let parsed = try? JSONDecoder().decode(KiroMcpOAuthRequestParams.self, from: data) {
                    agent.pendingOAuthURL = parsed.url
                }
            }
            agent.debugLog.append(DebugLogEntry(
                type: "kiro_mcp_oauth_request",
                summary: "OAuth request: \(agent.pendingOAuthURL ?? "unknown")",
                rawJson: rawJson
            ))
            
        default:
            agent.debugLog.append(DebugLogEntry(
                type: "kiro_unknown",
                summary: "Unknown Kiro notification: \(method)",
                rawJson: rawJson
            ))
        }
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
                // Accumulate thought text (skip during session replay)
                if !agent.isReplayingSession {
                    agent.thoughtContent += t.text
                }
            } else {
                entry = DebugLogEntry(type: "thought", summary: "(non-text)")
            }
        case .userMessageChunk:
            entry = DebugLogEntry(type: "user_echo", summary: "")
        case .planUpdate(let planUpdate):
            agent.currentPlan = planUpdate
            entry = DebugLogEntry(type: "plan", summary: "Plan: \(planUpdate.entries.count) steps")
        case .availableCommandsUpdate(let c):
            entry = DebugLogEntry(type: "commands", summary: c.availableCommands.map(\.name).joined(separator: ", "))
            agent.availableCommands = c.availableCommands
        case .currentModeUpdate(let m):
            entry = DebugLogEntry(type: "mode_update", summary: m.currentModeId.value)
            agent.currentModeId = m.currentModeId
        case .configOptionUpdate(let update):
            entry = DebugLogEntry(type: "config_update", summary: update.configOptions.map { 
                if case .select(let s) = $0 { return s.name }
                return "?"
            }.joined(separator: ", "))
            agent.configOptions = update.configOptions
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
        
        // Detect skill activation patterns like [skill: <name> activated]
        detectSkillActivation(in: text, for: agent)
    }
    
    private func detectSkillActivation(in text: String, for agent: Agent) {
        var searchRange = text.startIndex..<text.endIndex
        while let startRange = text.range(of: "[skill: ", range: searchRange) {
            let nameStart = startRange.upperBound
            guard let endRange = text.range(of: " activated]", range: nameStart..<text.endIndex) else {
                break
            }
            let skillName = String(text[nameStart..<endRange.lowerBound])
            if let idx = agent.availableSkills.firstIndex(where: { $0.name == skillName }) {
                agent.availableSkills[idx].isActive = true
            }
            searchRange = endRange.upperBound..<text.endIndex
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
        agent.thoughtContent = ""
        
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
    
    public func executeSlashCommand(agentId: UUID, command: String, args: [String: String] = [:]) async throws -> String? {
        throw AgentManagerError.platformNotSupported
    }
    
    public func requestCommandOptions(agentId: UUID, command: String, partial: String = "") async throws -> [CommandOption] {
        throw AgentManagerError.platformNotSupported
    }
    
    public func resolvePermission(agentId: UUID, optionId: String) {
        // No-op on non-macOS
    }
    
    public func cancelPermission(agentId: UUID) {
        // No-op on non-macOS
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
    
    public func setConfigOption(agentId: UUID, configId: String, value: String) async throws {
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
    
    public func executeSlashCommand(agentId: UUID, command: String, args: [String: String] = [:]) async throws -> String? {
        throw AgentManagerError.platformNotSupported
    }
    
    public func requestCommandOptions(agentId: UUID, command: String, partial: String = "") async throws -> [CommandOption] {
        throw AgentManagerError.platformNotSupported
    }
    
    public func resolvePermission(agentId: UUID, optionId: String) {
        // No-op on non-macOS
    }
    
    public func cancelPermission(agentId: UUID) {
        // No-op on non-macOS
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
    
    public func setConfigOption(agentId: UUID, configId: String, value: String) async throws {
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
