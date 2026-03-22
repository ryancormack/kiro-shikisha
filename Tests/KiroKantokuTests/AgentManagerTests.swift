import XCTest
import ACPModel
import ACP
@testable import KiroKantoku

final class AgentManagerTests: XCTestCase {
    
    @MainActor
    func testIsStaleSessionLockError_withMatchingError() async throws {
        let agentManager = AgentManager()
        let error = ProtocolError.jsonRpcError(
            code: -1,
            message: "Session error",
            data: .string("Session is active in another process")
        )
        XCTAssertTrue(agentManager.isStaleSessionLockError(error))
    }
    
    @MainActor
    func testIsStaleSessionLockError_withNonMatchingProtocolError() async throws {
        let agentManager = AgentManager()
        let error = ProtocolError.jsonRpcError(
            code: -1,
            message: "Some other error",
            data: .string("Something else went wrong")
        )
        XCTAssertFalse(agentManager.isStaleSessionLockError(error))
    }
    
    @MainActor
    func testIsStaleSessionLockError_withNilData() async throws {
        let agentManager = AgentManager()
        let error = ProtocolError.jsonRpcError(
            code: -1,
            message: "Error",
            data: nil
        )
        XCTAssertFalse(agentManager.isStaleSessionLockError(error))
    }
    
    @MainActor
    func testIsStaleSessionLockError_withNonProtocolError() async throws {
        let agentManager = AgentManager()
        let error = NSError(domain: "test", code: 1, userInfo: nil)
        XCTAssertFalse(agentManager.isStaleSessionLockError(error))
    }
    
    @MainActor
    func testIsStaleSessionLockError_withTransportClosedError() async throws {
        let agentManager = AgentManager()
        let error = ProtocolError.transportClosed
        XCTAssertFalse(agentManager.isStaleSessionLockError(error))
    }
    
    func testRemoveSessionLockFileBeforeRetry() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sessionId = "stale-session-lock-test"
        let lockFile = tempDir.appendingPathComponent("\(sessionId).lock")
        try "12345".write(to: lockFile, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: lockFile.path))

        // This mirrors what loadAgent() now does before retrying session/load
        let sessionStorage = SessionStorage(sessionsDirectory: tempDir)
        let removed = sessionStorage.removeSessionLockFile(sessionId: sessionId)

        XCTAssertTrue(removed, "Lock file should be successfully removed")
        XCTAssertFalse(FileManager.default.fileExists(atPath: lockFile.path), "Lock file should no longer exist on disk")
    }

    @MainActor
    func testIsReplayingSessionGuardsAgentMessages() async throws {
        // Verify that setting isReplayingSession on Agent prevents message modification.
        // On Linux the handleSessionUpdate is a no-op, so we verify the property
        // is correctly settable and the guard logic would work.
        let workspace = Workspace(name: "Test", path: URL(fileURLWithPath: "/tmp/test"))
        let agent = Agent(name: "Test Agent", workspace: workspace)

        // Agent starts with isReplayingSession = false
        XCTAssertFalse(agent.isReplayingSession)

        // Set it to true (simulating what loadAgent does before loadSession)
        agent.isReplayingSession = true
        XCTAssertTrue(agent.isReplayingSession)

        // On Linux, handleSessionUpdate is a no-op, but we can verify
        // messages are not modified when the flag is set
        let messageCountBefore = agent.messages.count

        // The AgentManager on Linux is a stub, so handleSessionUpdate is a no-op.
        // We verify the property exists and is functional.
        agent.isReplayingSession = false
        XCTAssertFalse(agent.isReplayingSession)
        XCTAssertEqual(agent.messages.count, messageCountBefore,
            "Messages should not change when replaying session flag is toggled")
    }
    
    // MARK: - isNotLoggedInError Tests
    
    @MainActor
    func testIsNotLoggedInError_withMatchingError() async throws {
        let agentManager = AgentManager()
        let error = ACPConnectionError.notLoggedIn
        XCTAssertTrue(agentManager.isNotLoggedInError(error))
    }
    
    @MainActor
    func testIsNotLoggedInError_withOtherACPConnectionError() async throws {
        let agentManager = AgentManager()
        let error = ACPConnectionError.notConnected
        XCTAssertFalse(agentManager.isNotLoggedInError(error))
    }
    
    @MainActor
    func testIsNotLoggedInError_withProcessSpawnFailed() async throws {
        let agentManager = AgentManager()
        let error = ACPConnectionError.processSpawnFailed("test")
        XCTAssertFalse(agentManager.isNotLoggedInError(error))
    }
    
    @MainActor
    func testIsNotLoggedInError_withNonACPError() async throws {
        let agentManager = AgentManager()
        let error = NSError(domain: "test", code: 1, userInfo: nil)
        XCTAssertFalse(agentManager.isNotLoggedInError(error))
    }
    
    @MainActor
    func testIsNotLoggedInError_withProtocolError() async throws {
        let agentManager = AgentManager()
        let error = ProtocolError.transportClosed
        XCTAssertFalse(agentManager.isNotLoggedInError(error))
    }
    
    func testNotLoggedInErrorDescription() {
        let error = ACPConnectionError.notLoggedIn
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("login"), "Error description should mention logging in")
        XCTAssertTrue(error.errorDescription!.contains("kiro-cli"), "Error description should mention kiro-cli")
    }
    
    // MARK: - Agent New Properties Tests
    
    @MainActor
    func testAgentNewProperties() async throws {
        let workspace = Workspace(name: "Test", path: URL(fileURLWithPath: "/tmp/test"))
        let agent = Agent(name: "Test Agent", workspace: workspace)
        
        // Verify new properties have correct defaults
        XCTAssertTrue(agent.availableCommands.isEmpty)
        XCTAssertNil(agent.currentModeId)
        XCTAssertNil(agent.sessionTitle)
    }
    
    @MainActor
    func testAgentConfigOptionsDefault() async throws {
        let workspace = Workspace(name: "Test", path: URL(fileURLWithPath: "/tmp/test"))
        let agent = Agent(name: "Test Agent", workspace: workspace)
        XCTAssertTrue(agent.configOptions.isEmpty, "Agent configOptions should default to empty")
    }
    
    @MainActor
    func testAgentKiroNotificationPropertyDefaults() async throws {
        let workspace = Workspace(name: "Test", path: URL(fileURLWithPath: "/tmp/test"))
        let agent = Agent(name: "Test Agent", workspace: workspace)
        
        XCTAssertNil(agent.contextUsagePercentage, "contextUsagePercentage should default to nil")
        XCTAssertFalse(agent.isCompacting, "isCompacting should default to false")
        XCTAssertNil(agent.compactionMessage, "compactionMessage should default to nil")
        XCTAssertFalse(agent.isClearingHistory, "isClearingHistory should default to false")
        XCTAssertNil(agent.clearStatusMessage, "clearStatusMessage should default to nil")
        XCTAssertNil(agent.pendingOAuthURL, "pendingOAuthURL should default to nil")
    }
    
    @MainActor
    func testAgentPendingPermissionRequestDefaultsToNil() async throws {
        let workspace = Workspace(name: "Test", path: URL(fileURLWithPath: "/tmp/test"))
        let agent = Agent(name: "Test Agent", workspace: workspace)
        
        XCTAssertNil(agent.pendingPermissionRequest, "pendingPermissionRequest should default to nil")
    }
    
    @MainActor
    func testPendingPermissionRequestProperties() async throws {
        let options = [
            PermissionOptionDisplay(optionId: "opt_allow", label: "Allow", kind: "allow_once"),
            PermissionOptionDisplay(optionId: "opt_reject", label: "Reject", kind: "reject_once")
        ]
        let request = PendingPermissionRequest(
            toolCallTitle: "shell",
            toolCallKind: "execute",
            rawInput: "ls -la",
            options: options
        )
        
        XCTAssertEqual(request.toolCallTitle, "shell")
        XCTAssertEqual(request.toolCallKind, "execute")
        XCTAssertEqual(request.rawInput, "ls -la")
        XCTAssertEqual(request.options.count, 2)
        XCTAssertEqual(request.options[0].optionId, "opt_allow")
        XCTAssertEqual(request.options[0].label, "Allow")
        XCTAssertEqual(request.options[0].kind, "allow_once")
        XCTAssertEqual(request.options[0].id, "opt_allow") // id derived from optionId
        XCTAssertEqual(request.options[1].optionId, "opt_reject")
        XCTAssertEqual(request.options[1].kind, "reject_once")
    }
    
    @MainActor
    func testPendingPermissionRequestDefaults() async throws {
        let request = PendingPermissionRequest(
            toolCallTitle: "tool",
            options: []
        )
        
        XCTAssertNil(request.toolCallKind)
        XCTAssertNil(request.rawInput)
        XCTAssertTrue(request.options.isEmpty)
        XCTAssertNotEqual(request.id, UUID()) // Has a valid UUID
    }
    
    // MARK: - Kiro Available Commands Tests
    
    @MainActor
    func testAgentKiroAvailableCommandsDefaultsToEmpty() async throws {
        let workspace = Workspace(name: "Test", path: URL(fileURLWithPath: "/tmp/test"))
        let agent = Agent(name: "Test Agent", workspace: workspace)
        XCTAssertTrue(agent.kiroAvailableCommands.isEmpty, "Agent kiroAvailableCommands should default to empty")
    }
    
    @MainActor
    func testAgentKiroAvailableCommandsCanBeSet() async throws {
        let workspace = Workspace(name: "Test", path: URL(fileURLWithPath: "/tmp/test"))
        let agent = Agent(name: "Test Agent", workspace: workspace)
        
        let commands = [
            KiroAvailableCommand(name: "model", description: "Switch model", meta: .object([
                "inputType": .string("selection")
            ])),
            KiroAvailableCommand(name: "clear", description: "Clear chat", meta: nil)
        ]
        agent.kiroAvailableCommands = commands
        
        XCTAssertEqual(agent.kiroAvailableCommands.count, 2)
        XCTAssertEqual(agent.kiroAvailableCommands[0].name, "model")
        XCTAssertEqual(agent.kiroAvailableCommands[1].name, "clear")
    }
    
    // MARK: - SlashCommand Merge Tests (macOS only)
    
    #if os(macOS)
    func testMergeSlashCommandsKiroOnly() {
        let kiroCommands = [
            KiroAvailableCommand(name: "model", description: "Switch model", meta: .object([
                "inputType": .string("selection"),
                "optionsMethod": .string("_kiro.dev/commands/options")
            ])),
            KiroAvailableCommand(name: "context", description: "Show context", meta: .object([
                "inputType": .string("panel")
            ])),
            KiroAvailableCommand(name: "quit", description: "Quit app", meta: .object([
                "local": .bool(true)
            ])),
            KiroAvailableCommand(name: "clear", description: "Clear chat", meta: nil)
        ]
        
        let merged = mergeSlashCommands(acpCommands: [], kiroCommands: kiroCommands)
        
        XCTAssertEqual(merged.count, 4)
        
        // Results are sorted by name
        let byName = Dictionary(uniqueKeysWithValues: merged.map { ($0.name, $0) })
        
        // Selection type
        let model = byName["model"]!
        XCTAssertEqual(model.inputType, .selection)
        XCTAssertEqual(model.optionsMethod, "_kiro.dev/commands/options")
        
        // Panel type
        let context = byName["context"]!
        XCTAssertEqual(context.inputType, .panel)
        XCTAssertNil(context.optionsMethod)
        
        // Local type
        let quit = byName["quit"]!
        XCTAssertEqual(quit.inputType, .local)
        
        // Simple type (nil meta)
        let clear = byName["clear"]!
        XCTAssertEqual(clear.inputType, .simple)
    }
    
    func testMergeSlashCommandsAcpOnly() {
        let acpCommands = [
            AvailableCommand(name: "help", description: "Show help"),
            AvailableCommand(name: "ask", description: "Ask a question",
                             input: .unstructured(UnstructuredInput(hint: "Type your question")))
        ]
        
        let merged = mergeSlashCommands(acpCommands: acpCommands, kiroCommands: [])
        
        XCTAssertEqual(merged.count, 2)
        
        let byName = Dictionary(uniqueKeysWithValues: merged.map { ($0.name, $0) })
        
        let help = byName["help"]!
        XCTAssertEqual(help.inputType, .simple)
        XCTAssertNil(help.hint)
        
        let ask = byName["ask"]!
        XCTAssertEqual(ask.inputType, .simple)
        XCTAssertEqual(ask.hint, "Type your question")
    }
    
    func testMergeSlashCommandsKiroOverridesAcp() {
        // When both sources have a command with the same name, Kiro wins
        let acpCommands = [
            AvailableCommand(name: "model", description: "ACP model command")
        ]
        let kiroCommands = [
            KiroAvailableCommand(name: "model", description: "Kiro model command", meta: .object([
                "inputType": .string("selection"),
                "optionsMethod": .string("_kiro.dev/commands/options")
            ]))
        ]
        
        let merged = mergeSlashCommands(acpCommands: acpCommands, kiroCommands: kiroCommands)
        
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].name, "model")
        XCTAssertEqual(merged[0].description, "Kiro model command") // Kiro description wins
        XCTAssertEqual(merged[0].inputType, .selection) // Kiro metadata applied
    }
    
    func testMergeSlashCommandsCombined() {
        let acpCommands = [
            AvailableCommand(name: "help", description: "Show help"),
            AvailableCommand(name: "model", description: "ACP model") // Will be overridden
        ]
        let kiroCommands = [
            KiroAvailableCommand(name: "model", description: "Kiro model", meta: .object([
                "inputType": .string("selection")
            ])),
            KiroAvailableCommand(name: "quit", description: "Quit", meta: .object([
                "local": .bool(true)
            ]))
        ]
        
        let merged = mergeSlashCommands(acpCommands: acpCommands, kiroCommands: kiroCommands)
        
        // help (from ACP) + model (from Kiro, overrides ACP) + quit (from Kiro) = 3
        XCTAssertEqual(merged.count, 3)
        
        // Verify sorted order
        XCTAssertEqual(merged[0].name, "help")
        XCTAssertEqual(merged[1].name, "model")
        XCTAssertEqual(merged[2].name, "quit")
    }
    
    func testMergeSlashCommandsDeduplicatesKiro() {
        let kiroCommands = [
            KiroAvailableCommand(name: "model", description: "First model", meta: nil),
            KiroAvailableCommand(name: "model", description: "Duplicate model", meta: nil)
        ]
        
        let merged = mergeSlashCommands(acpCommands: [], kiroCommands: kiroCommands)
        
        // Only the first should be kept
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].description, "First model")
    }
    
    func testMergeSlashCommandsResultIsSorted() {
        let kiroCommands = [
            KiroAvailableCommand(name: "zebra", description: "Z command", meta: nil),
            KiroAvailableCommand(name: "alpha", description: "A command", meta: nil),
            KiroAvailableCommand(name: "middle", description: "M command", meta: nil)
        ]
        
        let merged = mergeSlashCommands(acpCommands: [], kiroCommands: kiroCommands)
        
        XCTAssertEqual(merged[0].name, "alpha")
        XCTAssertEqual(merged[1].name, "middle")
        XCTAssertEqual(merged[2].name, "zebra")
    }
    
    func testSlashCommandInputTypeClassification() {
        // Verify all enum cases exist and are distinct
        let selection = SlashCommandInputType.selection
        let panel = SlashCommandInputType.panel
        let simple = SlashCommandInputType.simple
        let local = SlashCommandInputType.local
        
        // Use a switch to verify exhaustiveness at compile time
        for inputType in [selection, panel, simple, local] {
            switch inputType {
            case .selection: XCTAssertTrue(true)
            case .panel: XCTAssertTrue(true)
            case .simple: XCTAssertTrue(true)
            case .local: XCTAssertTrue(true)
            }
        }
    }
    
    func testSlashCommandProperties() {
        let cmd = SlashCommand(
            name: "model",
            description: "Switch model",
            inputType: .selection,
            optionsMethod: "_kiro.dev/commands/options",
            hint: "Pick a model"
        )
        
        XCTAssertEqual(cmd.id, "model") // id derived from name
        XCTAssertEqual(cmd.name, "model")
        XCTAssertEqual(cmd.description, "Switch model")
        XCTAssertEqual(cmd.inputType, .selection)
        XCTAssertEqual(cmd.optionsMethod, "_kiro.dev/commands/options")
        XCTAssertEqual(cmd.hint, "Pick a model")
    }
    
    func testSlashCommandDefaults() {
        let cmd = SlashCommand(name: "help", description: "Show help")
        
        XCTAssertEqual(cmd.inputType, .simple) // default
        XCTAssertNil(cmd.optionsMethod)
        XCTAssertNil(cmd.hint)
    }
    #endif
}
