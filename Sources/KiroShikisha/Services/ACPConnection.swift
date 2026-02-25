import Foundation

/// Errors that can occur during ACP connection operations
public enum ACPConnectionError: Error, Sendable {
    case notConnected
    case processSpawnFailed(String)
    case processTerminated(Int32)
    case encodingFailed
    case decodingFailed
    case streamClosed
    case platformNotSupported
}

#if os(macOS)

/// Actor that manages a kiro-cli subprocess for ACP communication
public actor ACPConnection {
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var messageStream: AsyncThrowingStream<Data, Error>?
    private var messageContinuation: AsyncThrowingStream<Data, Error>.Continuation?
    
    private let codec = ACPMessageCodec()
    
    /// Whether the connection is currently active
    public var isConnected: Bool {
        process?.isRunning ?? false
    }
    
    public init() {}
    
    /// Connect to kiro-cli by spawning a subprocess
    /// - Parameters:
    ///   - kirocliPath: Path to the kiro-cli executable
    ///   - agentConfig: Optional agent configuration path (passed via --agent flag)
    public func connect(kirocliPath: String, agentConfig: String? = nil) async throws {
        guard process == nil else {
            // Already connected
            return
        }
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: kirocliPath)
        
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
        
        // Set up the message stream before starting the process
        setupMessageStream()
        
        do {
            try proc.run()
            process = proc
        } catch {
            throw ACPConnectionError.processSpawnFailed(error.localizedDescription)
        }
        
        // Start reading from stdout in a background task
        startReadingMessages()
    }
    
    /// Disconnect from kiro-cli by terminating the subprocess
    public func disconnect() async {
        messageContinuation?.finish()
        messageContinuation = nil
        messageStream = nil
        
        if let proc = process, proc.isRunning {
            proc.terminate()
            proc.waitUntilExit()
        }
        
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
    }
    
    /// Send a JSON-RPC request to the kiro-cli process
    /// - Parameter request: The request to send
    public func send<Params: Encodable>(_ request: JSONRPCRequest<Params>) async throws {
        try await sendData(request)
    }
    
    /// Send a JSON-RPC notification to the kiro-cli process
    /// - Parameter notification: The notification to send
    public func sendNotification<Params: Encodable>(_ notification: JSONRPCNotification<Params>) async throws {
        try await sendData(notification)
    }
    
    /// Get a stream of incoming messages from the kiro-cli process
    /// - Returns: An AsyncThrowingStream that yields Data for each complete message
    public func receive() -> AsyncThrowingStream<Data, Error> {
        if let stream = messageStream {
            return stream
        }
        // Return an empty stream if not connected
        return AsyncThrowingStream { continuation in
            continuation.finish(throwing: ACPConnectionError.notConnected)
        }
    }
    
    // MARK: - Private Methods
    
    private func sendData<T: Encodable>(_ message: T) async throws {
        guard let stdin = stdinPipe?.fileHandleForWriting else {
            throw ACPConnectionError.notConnected
        }
        
        let data = try codec.encode(message)
        try stdin.write(contentsOf: data)
    }
    
    private func setupMessageStream() {
        let (stream, continuation) = AsyncThrowingStream<Data, Error>.makeStream()
        messageStream = stream
        messageContinuation = continuation
    }
    
    private func startReadingMessages() {
        guard let stdout = stdoutPipe?.fileHandleForReading,
              let continuation = messageContinuation else {
            return
        }
        
        // Capture what we need for the detached task
        let codec = self.codec
        
        Task.detached { [stdout, codec] in
            var buffer = Data()
            
            do {
                while let chunk = try stdout.availableData.isEmpty ? nil : stdout.availableData {
                    if chunk.isEmpty {
                        break
                    }
                    buffer.append(chunk)
                    
                    let (messages, remaining) = codec.parseMessages(from: buffer)
                    buffer = remaining
                    
                    for message in messages {
                        continuation.yield(message)
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
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
    
    public func connect(kirocliPath: String, agentConfig: String? = nil) async throws {
        throw ACPConnectionError.platformNotSupported
    }
    
    public func disconnect() async {
        // No-op on non-macOS
    }
    
    public func send<Params: Encodable>(_ request: JSONRPCRequest<Params>) async throws {
        throw ACPConnectionError.platformNotSupported
    }
    
    public func sendNotification<Params: Encodable>(_ notification: JSONRPCNotification<Params>) async throws {
        throw ACPConnectionError.platformNotSupported
    }
    
    public func receive() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: ACPConnectionError.platformNotSupported)
        }
    }
}

#endif
