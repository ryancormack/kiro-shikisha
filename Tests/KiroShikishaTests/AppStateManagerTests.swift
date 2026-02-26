import XCTest
@testable import KiroShikisha

final class AppStateManagerTests: XCTestCase {
    
    // MARK: - SessionRestorationStatus Tests
    
    func testSessionRestorationStatus_Equatable() {
        // Test basic equality
        XCTAssertEqual(SessionRestorationStatus.pending, SessionRestorationStatus.pending)
        XCTAssertEqual(SessionRestorationStatus.restoring, SessionRestorationStatus.restoring)
        XCTAssertEqual(SessionRestorationStatus.restored, SessionRestorationStatus.restored)
        XCTAssertEqual(SessionRestorationStatus.skipped, SessionRestorationStatus.skipped)
        XCTAssertEqual(SessionRestorationStatus.failed("error"), SessionRestorationStatus.failed("error"))
        
        // Test inequality
        XCTAssertNotEqual(SessionRestorationStatus.pending, SessionRestorationStatus.restoring)
        XCTAssertNotEqual(SessionRestorationStatus.failed("error1"), SessionRestorationStatus.failed("error2"))
    }
    
    func testSessionRestorationStatus_AllCases() {
        // Verify all status types can be created
        let pending: SessionRestorationStatus = .pending
        let restoring: SessionRestorationStatus = .restoring
        let restored: SessionRestorationStatus = .restored
        let skipped: SessionRestorationStatus = .skipped
        let failed: SessionRestorationStatus = .failed("Connection timeout")
        
        // Verify they're distinct
        XCTAssertNotEqual(pending, restoring)
        XCTAssertNotEqual(restoring, restored)
        XCTAssertNotEqual(restored, skipped)
        XCTAssertNotEqual(skipped, failed)
    }
    
    func testSessionRestorationStatus_FailedWithDifferentReasons() {
        let failed1 = SessionRestorationStatus.failed("Reason A")
        let failed2 = SessionRestorationStatus.failed("Reason B")
        let failed3 = SessionRestorationStatus.failed("Reason A")
        
        XCTAssertNotEqual(failed1, failed2)
        XCTAssertEqual(failed1, failed3)
    }
    
    // MARK: - SessionAssociation Tests
    
    func testSessionAssociation_Creation() {
        let association = SessionAssociation(sessionId: "session-123", cwd: "/path/to/workspace")
        XCTAssertEqual(association.sessionId, "session-123")
        XCTAssertEqual(association.cwd, "/path/to/workspace")
    }
    
    func testSessionAssociation_Equatable() {
        let association1 = SessionAssociation(sessionId: "session-123", cwd: "/path/to/workspace")
        let association2 = SessionAssociation(sessionId: "session-123", cwd: "/path/to/workspace")
        let association3 = SessionAssociation(sessionId: "session-456", cwd: "/path/to/workspace")
        let association4 = SessionAssociation(sessionId: "session-123", cwd: "/different/path")
        
        XCTAssertEqual(association1, association2)
        XCTAssertNotEqual(association1, association3)
        XCTAssertNotEqual(association1, association4)
    }
    
    func testSessionAssociation_Codable() throws {
        let association = SessionAssociation(sessionId: "session-123", cwd: "/path/to/workspace")
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(association)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SessionAssociation.self, from: data)
        
        XCTAssertEqual(association, decoded)
        XCTAssertEqual(decoded.sessionId, "session-123")
        XCTAssertEqual(decoded.cwd, "/path/to/workspace")
    }
    
    func testSessionAssociation_JSONFormat() throws {
        let association = SessionAssociation(sessionId: "test-session", cwd: "/test/path")
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(association)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("sessionId") || json.contains("session_id"))
        XCTAssertTrue(json.contains("test-session"))
        XCTAssertTrue(json.contains("/test/path") || json.contains("\\/test\\/path"))
    }
    
    func testSessionAssociation_DecodingFromJSON() throws {
        let json = """
        {
            "sessionId": "decoded-session",
            "cwd": "/decoded/path"
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let association = try decoder.decode(SessionAssociation.self, from: data)
        
        XCTAssertEqual(association.sessionId, "decoded-session")
        XCTAssertEqual(association.cwd, "/decoded/path")
    }
    
    // MARK: - Status Transition Logic Tests
    
    func testStatusTransitionPattern_SuccessfulFlow() {
        // Simulate the expected status flow for successful restoration
        var status: SessionRestorationStatus = .pending
        XCTAssertEqual(status, .pending)
        
        status = .restoring
        XCTAssertEqual(status, .restoring)
        
        status = .restored
        XCTAssertEqual(status, .restored)
    }
    
    func testStatusTransitionPattern_FailureFlow() {
        // Simulate the expected status flow for failed restoration
        var status: SessionRestorationStatus = .pending
        XCTAssertEqual(status, .pending)
        
        status = .restoring
        XCTAssertEqual(status, .restoring)
        
        status = .failed("Connection error")
        if case .failed(let reason) = status {
            XCTAssertEqual(reason, "Connection error")
        } else {
            XCTFail("Expected .failed status")
        }
    }
    
    func testStatusTransitionPattern_SkippedFlow() {
        // Simulate the flow when there's no valid session to restore
        var status: SessionRestorationStatus = .pending
        XCTAssertEqual(status, .pending)
        
        status = .skipped
        XCTAssertEqual(status, .skipped)
    }
    
    func testStatusDictionary_MultipleWorkspaces() {
        // Test using a dictionary similar to how AppStateManager stores statuses
        var statusDict: [UUID: SessionRestorationStatus] = [:]
        
        let workspace1 = UUID()
        let workspace2 = UUID()
        let workspace3 = UUID()
        
        statusDict[workspace1] = .pending
        statusDict[workspace2] = .restoring
        statusDict[workspace3] = .failed("Error")
        
        XCTAssertEqual(statusDict[workspace1], .pending)
        XCTAssertEqual(statusDict[workspace2], .restoring)
        XCTAssertEqual(statusDict[workspace3], .failed("Error"))
        
        // Clear one workspace
        statusDict.removeValue(forKey: workspace2)
        XCTAssertNil(statusDict[workspace2])
        
        // Others remain
        XCTAssertEqual(statusDict[workspace1], .pending)
        XCTAssertEqual(statusDict[workspace3], .failed("Error"))
    }
    
    func testStatusDictionary_Update() {
        var statusDict: [UUID: SessionRestorationStatus] = [:]
        let workspaceId = UUID()
        
        // Set initial status
        statusDict[workspaceId] = .pending
        XCTAssertEqual(statusDict[workspaceId], .pending)
        
        // Update status
        statusDict[workspaceId] = .restoring
        XCTAssertEqual(statusDict[workspaceId], .restoring)
        
        // Update to final status
        statusDict[workspaceId] = .restored
        XCTAssertEqual(statusDict[workspaceId], .restored)
    }
    
    // MARK: - Association Dictionary Tests
    
    func testAssociationDictionary_Storage() {
        var associations: [UUID: SessionAssociation] = [:]
        
        let workspaceId = UUID()
        let association = SessionAssociation(sessionId: "session-abc", cwd: "/workspace/path")
        
        associations[workspaceId] = association
        
        XCTAssertEqual(associations[workspaceId]?.sessionId, "session-abc")
        XCTAssertEqual(associations[workspaceId]?.cwd, "/workspace/path")
    }
    
    func testAssociationDictionary_Removal() {
        var associations: [UUID: SessionAssociation] = [:]
        
        let workspaceId = UUID()
        associations[workspaceId] = SessionAssociation(sessionId: "session-xyz", cwd: "/path")
        
        XCTAssertNotNil(associations[workspaceId])
        
        associations.removeValue(forKey: workspaceId)
        
        XCTAssertNil(associations[workspaceId])
    }
}
