import Foundation
import ACPModel
import ACP

/// Errors that can occur during ACP connection operations
public enum ACPConnectionError: Error, Sendable, LocalizedError {
    case notConnected
    case processSpawnFailed(String)
    case processTerminated(Int32)
    case platformNotSupported
    case notLoggedIn
    case timeout(String)
    case serverError(Int, String)
    
    public var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to kiro-cli process"
        case .processSpawnFailed(let msg): return "Failed to start kiro-cli: \(msg)"
        case .processTerminated(let code): return "kiro-cli exited with code \(code)"
        case .platformNotSupported: return "Platform not supported"
        case .notLoggedIn: return "Not logged in. Please run `kiro-cli login` in your terminal to authenticate."
        case .timeout(let method): return "Request timed out: \(method)"
        case .serverError(let code, let message): return "Server error (\(code)): \(message)"
        }
    }
}

#if os(macOS)

/// Transport implementation that communicates with a subprocess via pipes.
///
/// Unlike StdioTransport which uses standardInput/standardOutput, this transport
/// connects to a Process's stdin/stdout pipes for subprocess communication.
public final class ProcessTransport: Transport, @unchecked Sendable {
    private let stdinPipe: Pipe
    private let stdoutPipe: Pipe
    
    private let stateActor: ProcessTransportStateActor
    
    /// Handler for Kiro vendor extension notifications (_kiro.dev/*)
    public var kiroNotificationHandler: (@Sendable (String, JsonValue?) async -> Void)?
    
    /// Pending response handlers indexed by request ID
    private var pendingResponses: [RequestId: @Sendable (Result<JsonValue?, Error>) -> Void] = [:]
    private let pendingLock = NSLock()
    
    /// Register a handler for a pending response to a request
    public func registerPendingResponse(requestId: RequestId, handler: @escaping @Sendable (Result<JsonValue?, Error>) -> Void) {
        pendingLock.withLock {
            pendingResponses[requestId] = handler
        }
    }
    
    /// Remove a pending response handler
    public func removePendingResponse(requestId: RequestId) {
        pendingLock.withLock {
            pendingResponses.removeValue(forKey: requestId)
        }
    }
    
    /// Initialize with process pipes
    /// - Parameters:
    ///   - stdinPipe: Pipe connected to the subprocess's stdin
    ///   - stdoutPipe: Pipe connected to the subprocess's stdout
    public init(stdinPipe: Pipe, stdoutPipe: Pipe) {
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stateActor = ProcessTransportStateActor()
    }
    
    public var state: AsyncStream<TransportState> {
        stateActor.stateStream
    }
    
    public func start() async throws {
        try await stateActor.transitionTo(.starting)
        
        // Launch read/write loops as background tasks (must not block)
        Task { await self.readLoop() }
        Task { await self.writeLoop() }
        
        try await stateActor.transitionTo(.started)
    }
    
    public func send(_ message: JsonRpcMessage) async throws {
        try await stateActor.enqueue(message)
    }
    
    public var messages: AsyncStream<JsonRpcMessage> {
        stateActor.messageStream
    }
    
    public func close() async {
        // Clean up all pending response handlers so continuations don't leak
        let handlers: [RequestId: @Sendable (Result<JsonValue?, Error>) -> Void] = pendingLock.withLock {
            let current = pendingResponses
            pendingResponses.removeAll()
            return current
        }
        for (id, handler) in handlers {
            print("[ACP] Cleaning up pending response for id=\(id) on transport close")
            handler(.failure(ACPConnectionError.notConnected))
        }
        await stateActor.close()
    }
    
    // MARK: - Private Methods
    
    private func readLoop() async {
        defer {
            Task { await self.close() }
        }
        
        let handle = stdoutPipe.fileHandleForReading
        var buffer = Data()
        
        do {
            while !Task.isCancelled {
                // Read available data
                let chunk = try await Task {
                    handle.availableData
                }.value
                
                if chunk.isEmpty {
                    // End of stream
                    break
                }
                
                buffer.append(chunk)
                
                // Parse newline-delimited messages
                while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                    let messageData = buffer[buffer.startIndex..<newlineIndex]
                    buffer = Data(buffer[buffer.index(after: newlineIndex)...])
                    
                    if messageData.isEmpty {
                        continue
                    }
                    
                    // Decode JSON-RPC message
                    let decoder = JSONDecoder()
                    if let message = try? decoder.decode(JsonRpcMessage.self, from: Data(messageData)) {
                        // Check for pending response handlers (for vendor extension requests)
                        if case .response(let response) = message {
                            let handler = self.pendingLock.withLock {
                                self.pendingResponses.removeValue(forKey: response.id)
                            }
                            if let handler = handler {
                                print("[ACP] Pending response matched for id=\(response.id)")
                                handler(.success(response.result))
                                continue
                            }
                        }
                        // Check for error responses to pending vendor extension requests
                        if case .error(let error) = message, let id = error.id {
                            let handler = self.pendingLock.withLock {
                                self.pendingResponses.removeValue(forKey: id)
                            }
                            if let handler = handler {
                                print("[ACP] Pending error response matched for id=\(id): code=\(error.error.code) message=\(error.error.message)")
                                handler(.failure(ACPConnectionError.serverError(error.error.code, error.error.message)))
                                continue
                            }
                        }
                        // Check for Kiro vendor extension notifications
                        if case .notification(let notif) = message, notif.method.hasPrefix("_kiro.dev/") {
                            if let handler = self.kiroNotificationHandler {
                                let method = notif.method
                                let params = notif.params
                                Task { await handler(method, params) }
                            }
                        }
                        await stateActor.deliver(message)
                    } else {
                        let raw = String(data: Data(messageData), encoding: .utf8) ?? "undecodable"
                        print("[ProcessTransport] Failed to decode: \(raw.prefix(200))")
                    }
                }
            }
        } catch {
            print("[ProcessTransport] Read error: \(error)")
        }
    }
    
    private func writeLoop() async {
        defer {
            Task { await self.close() }
        }
        
        let handle = stdinPipe.fileHandleForWriting
        let encoder = JSONEncoder()
        
        do {
            for await message in stateActor.sendQueue {
                let data = try encoder.encode(message)
                var lineData = data
                lineData.append(UInt8(ascii: "\n"))
                
                try await Task {
                    try handle.write(contentsOf: lineData)
                }.value
            }
        } catch {
            print("[ProcessTransport] Write error: \(error)")
        }
    }
}

/// Actor managing ProcessTransport state
private actor ProcessTransportStateActor {
    private var currentState: TransportState = .created
    private let stateContinuation: AsyncStream<TransportState>.Continuation
    private let messageContinuation: AsyncStream<JsonRpcMessage>.Continuation
    private let sendContinuation: AsyncStream<JsonRpcMessage>.Continuation
    
    let stateStream: AsyncStream<TransportState>
    let messageStream: AsyncStream<JsonRpcMessage>
    let sendQueue: AsyncStream<JsonRpcMessage>
    
    init() {
        (stateStream, stateContinuation) = AsyncStream.makeStream()
        (messageStream, messageContinuation) = AsyncStream.makeStream()
        (sendQueue, sendContinuation) = AsyncStream.makeStream()
        
        stateContinuation.yield(.created)
    }
    
    func transitionTo(_ newState: TransportState) throws {
        switch (currentState, newState) {
        case (.created, .starting),
             (.starting, .started),
             (.started, .closing),
             (.starting, .closing),
             (.closing, .closed):
            currentState = newState
            stateContinuation.yield(newState)
            
            if newState == .closed {
                stateContinuation.finish()
                messageContinuation.finish()
                sendContinuation.finish()
            }
        default:
            break // Ignore invalid transitions
        }
    }
    
    func enqueue(_ message: JsonRpcMessage) throws {
        guard currentState == .started else {
            throw ACPConnectionError.notConnected
        }
        sendContinuation.yield(message)
    }
    
    func deliver(_ message: JsonRpcMessage) {
        messageContinuation.yield(message)
    }
    
    func close() {
        if currentState != .closed && currentState != .closing {
            try? transitionTo(.closing)
            sendContinuation.finish()
            
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                try? self.transitionTo(.closed)
            }
        }
    }
}

/// Actor that manages a kiro-cli subprocess for ACP communication using the SDK's ClientConnection.
public actor ACPConnection {
    private var process: Process?

    /// PID of the kiro-cli process, if running
    public var processId: Int32? {
        process?.isRunning == true ? process?.processIdentifier : nil
    }
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    
    private var clientConnection: ClientConnection?
    private var kiroClient: KiroClient?
    private var transport: ProcessTransport?
    
    /// Whether the connection is currently active
    public var isConnected: Bool {
        process?.isRunning ?? false
    }
    
    public init() {}
    
    /// Connect to kiro-cli by spawning a subprocess
    /// - Parameters:
    ///   - kirocliPath: Path to the kiro-cli executable
    ///   - agentConfig: Optional agent configuration path (passed via --agent flag)
    ///   - onSessionUpdate: Callback for session updates
    ///   - onKiroNotification: Optional callback for Kiro vendor extension notifications (_kiro.dev/*)
    ///   - onPermissionRequest: Optional callback for permission requests from the agent
    public func connect(
        kirocliPath: String,
        agentConfig: String? = nil,
        onSessionUpdate: @escaping @Sendable (SessionUpdate) async -> Void,
        onKiroNotification: (@Sendable (String, JsonValue?) async -> Void)? = nil,
        onPermissionRequest: ((@Sendable (ToolCallUpdateData, [PermissionOption], @escaping @Sendable (RequestPermissionOutcome) -> Void) -> Void))? = nil
    ) async throws {
        guard process == nil else {
            // Already connected
            return
        }
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: kirocliPath.hasPrefix("~")
            ? kirocliPath.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path, options: .anchored)
            : kirocliPath)
        
        var arguments = ["acp"]
        if let config = agentConfig {
            arguments.append("--agent")
            arguments.append(config)
        }
        proc.arguments = arguments
        
        // Set up pipes for communication
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr
        
        stdinPipe = stdin
        stdoutPipe = stdout
        stderrPipe = stderr
        
        do {
            try proc.run()
            process = proc
        } catch {
            throw ACPConnectionError.processSpawnFailed(error.localizedDescription)
        }
        
        // Log stderr in background and accumulate for error detection
        nonisolated(unsafe) var stderrBuffer = ""
        nonisolated(unsafe) var stderrFinished = false
        Task.detached { @Sendable [stderr] in
            while true {
                let data = stderr.fileHandleForReading.availableData
                if data.isEmpty {
                    stderrFinished = true
                    break
                }
                if let text = String(data: data, encoding: .utf8) {
                    print("[ACP-stderr] \(text)")
                    stderrBuffer += text
                }
            }
        }
        
        // Create transport with process pipes
        let processTransport = ProcessTransport(stdinPipe: stdin, stdoutPipe: stdout)
        processTransport.kiroNotificationHandler = onKiroNotification
        transport = processTransport
        
        // Create client with session update callback
        let client = KiroClient()
        client.onSessionUpdateCallback = onSessionUpdate
        client.onPermissionRequest = onPermissionRequest
        kiroClient = client
        
        // Create and connect ClientConnection
        let connection = ClientConnection(transport: processTransport, client: client)
        clientConnection = connection
        
        // Connect performs initialization
        do {
            _ = try await connection.connect()
        } catch {
            // Brief delay to let stderr data accumulate
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            let stderrText = stderrBuffer
            if stderrText.localizedCaseInsensitiveContains("not logged in") ||
               stderrText.localizedCaseInsensitiveContains("please log in with kiro-cli login") {
                throw ACPConnectionError.notLoggedIn
            }
            throw error
        }
    }

    /// Synchronously kill the kiro-cli process (for app quit)
    public func killProcess() {
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
    }

    /// Disconnect from kiro-cli by terminating the subprocess
    public func disconnect() async {
        // Disconnect the client connection
        if let connection = clientConnection {
            await connection.disconnect()
        }
        clientConnection = nil
        kiroClient = nil
        
        // Close transport
        if let transport = transport {
            await transport.close()
        }
        transport = nil
        
        if let proc = process, proc.isRunning {
            proc.terminate()
            proc.waitUntilExit()
        }
        
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
    }
    
    /// Create a new session
    /// - Parameter cwd: Current working directory
    /// - Returns: Session response containing sessionId
    public func createSession(cwd: String) async throws -> NewSessionResponse {
        guard let connection = clientConnection else {
            throw ACPConnectionError.notConnected
        }
        
        let request = NewSessionRequest(cwd: cwd, mcpServers: [])
        return try await connection.createSession(request: request)
    }
    
    /// Load an existing session
    /// - Parameters:
    ///   - sessionId: Session ID to load
    ///   - cwd: Current working directory
    /// - Returns: Load session response
    public func loadSession(sessionId: SessionId, cwd: String) async throws -> LoadSessionResponse {
        guard let connection = clientConnection else {
            throw ACPConnectionError.notConnected
        }
        
        let request = LoadSessionRequest(sessionId: sessionId, cwd: cwd, mcpServers: [])
        return try await connection.loadSession(request: request)
    }
    
    /// Send a prompt to the agent
    /// - Parameters:
    ///   - sessionId: Session ID
    ///   - prompt: Content blocks for the prompt
    /// - Returns: Prompt response with stop reason
    public func prompt(sessionId: SessionId, prompt: [ContentBlock]) async throws -> PromptResponse {
        guard let connection = clientConnection else {
            throw ACPConnectionError.notConnected
        }
        
        let request = PromptRequest(sessionId: sessionId, prompt: prompt)
        return try await connection.prompt(request: request)
    }
    
    /// Set the session mode (e.g., switch between agent configurations like "code" vs "chat")
    public func setSessionMode(sessionId: SessionId, modeId: SessionModeId) async throws {
        guard let connection = clientConnection else {
            throw ACPConnectionError.notConnected
        }
        let request = SetSessionModeRequest(sessionId: sessionId, modeId: modeId)
        _ = try await connection.setSessionMode(request: request)
    }

    /// Set the model for the session
    public func setSessionModel(sessionId: SessionId, modelId: ModelId) async throws {
        guard let connection = clientConnection else {
            throw ACPConnectionError.notConnected
        }
        let request = SetSessionModelRequest(sessionId: sessionId, modelId: modelId)
        _ = try await connection.setSessionModel(request: request)
    }

    /// Set a configuration option for the session
    public func setSessionConfigOption(sessionId: SessionId, configId: SessionConfigId, value: SessionConfigValueId) async throws {
        guard let connection = clientConnection else {
            throw ACPConnectionError.notConnected
        }
        let request = SetSessionConfigOptionRequest(sessionId: sessionId, configId: configId, value: value)
        _ = try await connection.setSessionConfigOption(request: request)
    }

    /// Send a session/cancel notification to the server
    public func cancelSession(sessionId: SessionId) async throws {
        guard let transport = transport else {
            throw ACPConnectionError.notConnected
        }
        
        let notification = CancelNotification(sessionId: sessionId)
        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)
        let paramsValue = try JSONDecoder().decode(JsonValue.self, from: data)
        
        let rpcNotification = JsonRpcNotification(method: "session/cancel", params: paramsValue)
        try await transport.send(.notification(rpcNotification))
    }
    
    /// Execute a slash command via the Kiro extension protocol.
    /// Registers a pending response handler and awaits the JSON-RPC response,
    /// preventing it from being forwarded to the SDK's ClientConnection.
    /// The actual command output arrives through normal session updates (agent message chunks).
    @discardableResult
    public func executeSlashCommand(sessionId: SessionId, commandName: String, args: [String: String] = [:]) async throws -> String? {
        guard let transport = transport else {
            throw ACPConnectionError.notConnected
        }
        
        // Build args as JsonValue object
        var argsObject: [String: JsonValue] = [:]
        for (key, value) in args {
            argsObject[key] = .string(value)
        }
        
        // Strip leading "/" if present
        let name = commandName.hasPrefix("/") ? String(commandName.dropFirst()) : commandName
        
        // Build the TuiCommand format: {"command": "<name>", "args": {<args>}}
        let commandObject: JsonValue = .object([
            "command": .string(name),
            "args": .object(argsObject)
        ])
        
        let requestId = Int.random(in: 10000...99999)
        let paramsValue: JsonValue = .object([
            "sessionId": .string(sessionId.value),
            "command": commandObject
        ])
        
        let request = JsonRpcRequest(id: .int(requestId), method: "_kiro.dev/commands/execute", params: paramsValue)
        
        print("[ACP] executeSlashCommand: command=\(name) requestId=\(requestId)")
        
        // Register a pending response handler before sending, so the response
        // is consumed here rather than being forwarded to the SDK's ClientConnection.
        // Uses AsyncThrowingStream to bridge the callback-based handler to async/await,
        // and withThrowingTaskGroup to race the response against a 30-second timeout.
        let (responseStream, responseContinuation) = AsyncThrowingStream<JsonValue?, Error>.makeStream()
        
        transport.registerPendingResponse(requestId: .int(requestId)) { callResult in
            switch callResult {
            case .success(let value):
                print("[ACP] executeSlashCommand: response received for requestId=\(requestId)")
                responseContinuation.yield(value)
                responseContinuation.finish()
            case .failure(let error):
                print("[ACP] executeSlashCommand: error received for requestId=\(requestId): \(error)")
                responseContinuation.finish(throwing: error)
            }
        }
        
        let result: JsonValue?
        do {
            result = try await withThrowingTaskGroup(of: JsonValue?.self) { group in
                group.addTask {
                    var iterator = responseStream.makeAsyncIterator()
                    return try await iterator.next() ?? nil
                }
                
                group.addTask {
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                    print("[ACP] executeSlashCommand: timeout for requestId=\(requestId)")
                    throw ACPConnectionError.timeout("_kiro.dev/commands/execute")
                }
                
                // Send the request (handler is already registered above)
                try await transport.send(.request(request))
                print("[ACP] executeSlashCommand: request sent for requestId=\(requestId)")
                
                // Wait for whichever child task finishes first
                let value = try await group.next()!
                group.cancelAll()
                return value
            }
        } catch {
            // Clean up pending response handler on timeout or send failure
            transport.removePendingResponse(requestId: .int(requestId))
            responseContinuation.finish()
            throw error
        }
        
        // Clean up pending response handler (no-op if already removed by readLoop)
        transport.removePendingResponse(requestId: .int(requestId))
        responseContinuation.finish()
        
        // Extract a message string from the response if present.
        // Try multiple common field names since different servers may use different keys.
        if let result = result {
            // If the result is directly a string, use it
            if case .string(let message) = result {
                return message
            }
            // If the result is an object, try known field names
            if case .object(let obj) = result {
                for key in ["message", "text", "content"] {
                    if case .string(let value) = obj[key] {
                        return value
                    }
                }
                // Fallback: serialize the entire result object to JSON
                if let data = try? JSONEncoder().encode(result),
                   let jsonString = String(data: data, encoding: .utf8) {
                    return jsonString
                }
            }
        }
        return nil
    }
    
    /// Request available options for a selection-type slash command.
    /// The response is delivered via the kiroResponseHandler on the transport.
    public func requestCommandOptions(sessionId: SessionId, command: String, partial: String = "") async throws -> [CommandOption] {
        guard let transport = transport else {
            throw ACPConnectionError.notConnected
        }
        
        // Strip leading "/" if present
        let name = command.hasPrefix("/") ? String(command.dropFirst()) : command
        
        let requestId = Int.random(in: 10000...99999)
        let paramsValue: JsonValue = .object([
            "command": .string(name),
            "sessionId": .string(sessionId.value),
            "partial": .string(partial)
        ])
        
        let request = JsonRpcRequest(id: .int(requestId), method: "_kiro.dev/commands/options", params: paramsValue)
        
        print("[ACP] requestCommandOptions: command=\(name) requestId=\(requestId)")
        
        // Register a pending response handler before sending.
        // Uses AsyncThrowingStream to bridge the callback-based handler to async/await,
        // and withThrowingTaskGroup to race the response against a 30-second timeout.
        let (responseStream, responseContinuation) = AsyncThrowingStream<[CommandOption], Error>.makeStream()
        
        transport.registerPendingResponse(requestId: .int(requestId)) { callResult in
            switch callResult {
            case .success(let result):
                print("[ACP] requestCommandOptions: response received for requestId=\(requestId)")
                if let result = result {
                    do {
                        let data = try JSONEncoder().encode(result)
                        let decoded = try JSONDecoder().decode(CommandOptionsResponse.self, from: data)
                        responseContinuation.yield(decoded.options)
                        responseContinuation.finish()
                    } catch {
                        responseContinuation.finish(throwing: error)
                    }
                } else {
                    responseContinuation.yield([])
                    responseContinuation.finish()
                }
            case .failure(let error):
                print("[ACP] requestCommandOptions: error received for requestId=\(requestId): \(error)")
                responseContinuation.finish(throwing: error)
            }
        }
        
        let options: [CommandOption]
        do {
            options = try await withThrowingTaskGroup(of: [CommandOption].self) { group in
                group.addTask {
                    var iterator = responseStream.makeAsyncIterator()
                    return try await iterator.next() ?? []
                }
                
                group.addTask {
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                    print("[ACP] requestCommandOptions: timeout for requestId=\(requestId)")
                    throw ACPConnectionError.timeout("_kiro.dev/commands/options")
                }
                
                // Send the request (handler is already registered above)
                try await transport.send(.request(request))
                print("[ACP] requestCommandOptions: request sent for requestId=\(requestId)")
                
                // Wait for whichever child task finishes first
                let value = try await group.next()!
                group.cancelAll()
                return value
            }
        } catch {
            // Clean up pending response handler on timeout or send failure
            transport.removePendingResponse(requestId: .int(requestId))
            responseContinuation.finish()
            throw error
        }
        
        // Clean up pending response handler (no-op if already removed by readLoop)
        transport.removePendingResponse(requestId: .int(requestId))
        responseContinuation.finish()
        
        return options
    }
    
    /// Get the agent capabilities from initialization
    public func getAgentCapabilities() -> AgentCapabilities? {
        // ClientConnection stores this after connect()
        // We need to access it through the clientConnection actor
        // For now, return nil - this information isn't critical
        return nil
    }
}

#else

/// Stub implementation for non-macOS platforms (Linux)
/// Process APIs are macOS-specific, so this provides a placeholder
public actor ACPConnection {
    
    public var isConnected: Bool {
        false
    }
    
    public init() {}
    
    public func connect(
        kirocliPath: String,
        agentConfig: String? = nil,
        onSessionUpdate: @escaping @Sendable (SessionUpdate) async -> Void,
        onKiroNotification: (@Sendable (String, JsonValue?) async -> Void)? = nil,
        onPermissionRequest: ((@Sendable (ToolCallUpdateData, [PermissionOption], @escaping @Sendable (RequestPermissionOutcome) -> Void) -> Void))? = nil
    ) async throws {
        throw ACPConnectionError.platformNotSupported
    }
    
    public func disconnect() async {
        // No-op on non-macOS
    }
    
    public func createSession(cwd: String) async throws -> NewSessionResponse {
        throw ACPConnectionError.platformNotSupported
    }
    
    public func loadSession(sessionId: SessionId, cwd: String) async throws -> LoadSessionResponse {
        throw ACPConnectionError.platformNotSupported
    }
    
    public func prompt(sessionId: SessionId, prompt: [ContentBlock]) async throws -> PromptResponse {
        throw ACPConnectionError.platformNotSupported
    }
    
    public func setSessionMode(sessionId: SessionId, modeId: SessionModeId) async throws {
        throw ACPConnectionError.platformNotSupported
    }

    public func setSessionModel(sessionId: SessionId, modelId: ModelId) async throws {
        throw ACPConnectionError.platformNotSupported
    }

    public func setSessionConfigOption(sessionId: SessionId, configId: SessionConfigId, value: SessionConfigValueId) async throws {
        throw ACPConnectionError.platformNotSupported
    }

    public func cancelSession(sessionId: SessionId) async throws {
        throw ACPConnectionError.platformNotSupported
    }
    
    public func executeSlashCommand(sessionId: SessionId, commandName: String, args: [String: String] = [:]) async throws -> String? {
        throw ACPConnectionError.platformNotSupported
    }
    
    public func requestCommandOptions(sessionId: SessionId, command: String, partial: String = "") async throws -> [CommandOption] {
        throw ACPConnectionError.platformNotSupported
    }
    
    public func getAgentCapabilities() -> AgentCapabilities? {
        return nil
    }
}

#endif
