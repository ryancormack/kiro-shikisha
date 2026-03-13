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
}
