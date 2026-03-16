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
    
    public var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to kiro-cli process"
        case .processSpawnFailed(let msg): return "Failed to start kiro-cli: \(msg)"
        case .processTerminated(let code): return "kiro-cli exited with code \(code)"
        case .platformNotSupported: return "Platform not supported"
        case .notLoggedIn: return "Not logged in. Please run `kiro-cli login` in your terminal to authenticate."
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
    public func connect(
        kirocliPath: String,
        agentConfig: String? = nil,
        onSessionUpdate: @escaping @Sendable (SessionUpdate) async -> Void
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
        Task.detached { [stderr] in
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
        transport = processTransport
        
        // Create client with session update callback
        let client = KiroClient()
        client.onSessionUpdateCallback = onSessionUpdate
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
        onSessionUpdate: @escaping @Sendable (SessionUpdate) async -> Void
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
    
    public func getAgentCapabilities() -> AgentCapabilities? {
        return nil
    }
}

#endif
