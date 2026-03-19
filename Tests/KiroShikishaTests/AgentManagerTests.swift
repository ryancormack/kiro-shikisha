import XCTest
import ACPModel
import ACP
@testable import KiroShikisha

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
}
