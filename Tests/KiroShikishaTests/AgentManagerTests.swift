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
}
