import Foundation
import ACPModel
import ACP

/// Actor managing terminal state for KiroClient
private actor TerminalStore {
    struct State {
        let process: Process
        let outputPipe: Pipe
        let outputByteLimit: UInt64?
        var accumulatedOutput = Data()
    }

    private var terminals: [String: State] = [:]

    func add(_ id: String, _ state: State) { terminals[id] = state }
    func get(_ id: String) -> State? { terminals[id] }
    func remove(_ id: String) -> State? { terminals.removeValue(forKey: id) }

    func appendOutput(_ id: String, _ data: Data) {
        terminals[id]?.accumulatedOutput.append(data)
        if let limit = terminals[id]?.outputByteLimit,
           let count = terminals[id]?.accumulatedOutput.count,
           count > Int(limit) {
            terminals[id]?.accumulatedOutput.removeFirst(count - Int(limit))
        }
    }
}

/// Client implementation for KiroKantoku that conforms to the ACP SDK's Client protocol.
public final class KiroClient: Client, ClientSessionOperations, @unchecked Sendable {
    public var onSessionUpdateCallback: (@Sendable (SessionUpdate) async -> Void)?
    public var onConnectedCallback: (@Sendable () async -> Void)?
    public var onDisconnectedCallback: (@Sendable (Error?) async -> Void)?

    private let terminalStore = TerminalStore()

    public init() {}

    // MARK: - Client Protocol

    public var capabilities: ClientCapabilities {
        ClientCapabilities(
            fs: FileSystemCapability(readTextFile: true, writeTextFile: true),
            terminal: true
        )
    }

    public var info: Implementation? {
        Implementation(name: "KiroKantoku", version: "1.0.0")
    }

    public func onSessionUpdate(_ update: SessionUpdate) async {
        await onSessionUpdateCallback?(update)
    }

    public func onConnected() async {
        await onConnectedCallback?()
    }

    public func onDisconnected(error: Error?) async {
        await onDisconnectedCallback?(error)
    }

    // MARK: - Permissions

    public func requestPermissions(
        toolCall: ToolCallUpdateData,
        permissions: [PermissionOption],
        meta: MetaField?
    ) async throws -> RequestPermissionResponse {
        let option = permissions.first { $0.kind == .allowOnce }
            ?? permissions.first { $0.kind == .allowAlways }
            ?? permissions.first
        guard let selected = option else {
            throw ClientError.requestFailed("No permission options provided")
        }
        return RequestPermissionResponse(outcome: .selected(selected.optionId))
    }

    public func notify(notification: SessionUpdate, meta: MetaField?) async {
        await onSessionUpdateCallback?(notification)
    }

    // MARK: - File System

    public func readTextFile(path: String, line: UInt32?, limit: UInt32?, meta: MetaField?) async throws -> ReadTextFileResponse {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        if let startLine = line {
            let lines = content.components(separatedBy: "\n")
            let start = max(0, Int(startLine) - 1)
            let end = limit.map { min(lines.count, start + Int($0)) } ?? lines.count
            guard start < lines.count else { return ReadTextFileResponse(content: "") }
            return ReadTextFileResponse(content: lines[start..<end].joined(separator: "\n"))
        }
        return ReadTextFileResponse(content: content)
    }

    public func writeTextFile(path: String, content: String, meta: MetaField?) async throws -> WriteTextFileResponse {
        let dir = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return WriteTextFileResponse()
    }

    // MARK: - Terminal

    public func terminalCreate(request: CreateTerminalRequest) async throws -> CreateTerminalResponse {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = [request.command] + request.args
        if let cwd = request.cwd { proc.currentDirectoryURL = URL(fileURLWithPath: cwd) }
        if !request.env.isEmpty {
            var env = ProcessInfo.processInfo.environment
            for v in request.env { env[v.name] = v.value }
            proc.environment = env
        }

        let outputPipe = Pipe()
        proc.standardOutput = outputPipe
        proc.standardError = outputPipe
        try proc.run()

        let terminalId = UUID().uuidString
        await terminalStore.add(terminalId, .init(process: proc, outputPipe: outputPipe, outputByteLimit: request.outputByteLimit))

        let store = terminalStore
        Task.detached {
            while true {
                let data = outputPipe.fileHandleForReading.availableData
                if data.isEmpty { break }
                await store.appendOutput(terminalId, data)
            }
        }

        return CreateTerminalResponse(terminalId: terminalId)
    }

    public func terminalOutput(sessionId: SessionId, terminalId: String, meta: MetaField?) async throws -> TerminalOutputResponse {
        guard let state = await terminalStore.get(terminalId) else {
            throw ClientError.requestFailed("Terminal not found")
        }
        let output = String(data: state.accumulatedOutput, encoding: .utf8) ?? ""
        let truncated = state.outputByteLimit != nil && state.accumulatedOutput.count >= Int(state.outputByteLimit!)
        let exitStatus: TerminalExitStatus? = state.process.isRunning ? nil : TerminalExitStatus(exitCode: UInt32(state.process.terminationStatus))
        return TerminalOutputResponse(output: output, truncated: truncated, exitStatus: exitStatus)
    }

    public func terminalRelease(sessionId: SessionId, terminalId: String, meta: MetaField?) async throws -> ReleaseTerminalResponse {
        guard let state = await terminalStore.remove(terminalId) else {
            throw ClientError.requestFailed("Terminal not found")
        }
        if state.process.isRunning { state.process.terminate() }
        return ReleaseTerminalResponse()
    }

    public func terminalWaitForExit(sessionId: SessionId, terminalId: String, meta: MetaField?) async throws -> WaitForTerminalExitResponse {
        guard let state = await terminalStore.get(terminalId) else {
            throw ClientError.requestFailed("Terminal not found")
        }
        state.process.waitUntilExit()
        return WaitForTerminalExitResponse(exitCode: UInt32(state.process.terminationStatus))
    }

    public func terminalKill(sessionId: SessionId, terminalId: String, meta: MetaField?) async throws -> KillTerminalCommandResponse {
        guard let state = await terminalStore.get(terminalId) else {
            throw ClientError.requestFailed("Terminal not found")
        }
        if state.process.isRunning { state.process.terminate() }
        return KillTerminalCommandResponse()
    }
}
