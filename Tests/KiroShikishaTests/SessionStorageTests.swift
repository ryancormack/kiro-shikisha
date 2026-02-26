import XCTest
@testable import KiroShikisha

final class SessionStorageTests: XCTestCase {
    
    private var tempDirectory: URL!
    private var sessionStorage: SessionStorage!
    
    override func setUp() async throws {
        // Create a temporary directory for test sessions
        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("KiroShikishaTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempPath, withIntermediateDirectories: true)
        tempDirectory = tempPath
        sessionStorage = SessionStorage(sessionsDirectory: tempPath)
    }
    
    override func tearDown() async throws {
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        sessionStorage = nil
    }
    
    // MARK: - Session Validation Tests
    
    func testValidateSession_ValidSession() throws {
        // Create a valid session
        let sessionId = "valid-session-123"
        let metadataJSON = """
        {
            "session_id": "\(sessionId)",
            "cwd": "/Users/test/myproject",
            "created_at": 1700000000.0
        }
        """
        
        let metadataURL = tempDirectory.appendingPathComponent("\(sessionId).json")
        try metadataJSON.data(using: .utf8)!.write(to: metadataURL)
        
        let result = sessionStorage.validateSession(sessionId: sessionId)
        XCTAssertEqual(result, .valid)
    }
    
    func testValidateSession_NotFound() throws {
        let result = sessionStorage.validateSession(sessionId: "nonexistent-session")
        XCTAssertEqual(result, .notFound)
    }
    
    func testValidateSession_MalformedJSON() throws {
        let sessionId = "malformed-session"
        let malformedJSON = "{ this is not valid JSON }"
        
        let metadataURL = tempDirectory.appendingPathComponent("\(sessionId).json")
        try malformedJSON.data(using: .utf8)!.write(to: metadataURL)
        
        let result = sessionStorage.validateSession(sessionId: sessionId)
        if case .invalid(let reason) = result {
            XCTAssertTrue(reason.contains("decode") || reason.contains("JSON"), "Expected decode error, got: \(reason)")
        } else {
            XCTFail("Expected .invalid result, got \(result)")
        }
    }
    
    func testValidateSession_MissingRequiredField() throws {
        let sessionId = "missing-cwd"
        // Missing cwd field
        let incompleteJSON = """
        {
            "session_id": "\(sessionId)"
        }
        """
        
        let metadataURL = tempDirectory.appendingPathComponent("\(sessionId).json")
        try incompleteJSON.data(using: .utf8)!.write(to: metadataURL)
        
        let result = sessionStorage.validateSession(sessionId: sessionId)
        if case .invalid = result {
            // Expected - missing required field
        } else {
            XCTFail("Expected .invalid result for missing required field, got \(result)")
        }
    }
    
    func testValidateSession_EmptyCwd() throws {
        let sessionId = "empty-cwd"
        let jsonWithEmptyCwd = """
        {
            "session_id": "\(sessionId)",
            "cwd": ""
        }
        """
        
        let metadataURL = tempDirectory.appendingPathComponent("\(sessionId).json")
        try jsonWithEmptyCwd.data(using: .utf8)!.write(to: metadataURL)
        
        let result = sessionStorage.validateSession(sessionId: sessionId)
        // Empty cwd is caught during metadata loading, so we get an invalid result
        // The reason may mention "empty", "cwd", or "decode" depending on where it's caught
        if case .invalid = result {
            // Expected - metadata with empty cwd should be considered invalid
        } else {
            XCTFail("Expected .invalid result for empty cwd, got \(result)")
        }
    }
    
    func testValidateSession_SessionIdMismatch() throws {
        let sessionId = "filename-id"
        let jsonWithDifferentId = """
        {
            "session_id": "different-id",
            "cwd": "/test/path"
        }
        """
        
        let metadataURL = tempDirectory.appendingPathComponent("\(sessionId).json")
        try jsonWithDifferentId.data(using: .utf8)!.write(to: metadataURL)
        
        let result = sessionStorage.validateSession(sessionId: sessionId)
        if case .invalid(let reason) = result {
            XCTAssertTrue(reason.contains("match") || reason.contains("different-id"), "Expected mismatch error, got: \(reason)")
        } else {
            XCTFail("Expected .invalid result for session_id mismatch, got \(result)")
        }
    }
    
    // MARK: - Load Session Metadata Tests
    
    func testLoadSessionMetadata_Valid() throws {
        let sessionId = "test-meta"
        let metadataJSON = """
        {
            "session_id": "\(sessionId)",
            "cwd": "/Users/test/workspace",
            "session_name": "My Test Session"
        }
        """
        
        let metadataURL = tempDirectory.appendingPathComponent("\(sessionId).json")
        try metadataJSON.data(using: .utf8)!.write(to: metadataURL)
        
        let metadata = try sessionStorage.getSessionMetadata(sessionId: sessionId)
        XCTAssertNotNil(metadata)
        XCTAssertEqual(metadata?.sessionId, sessionId)
        XCTAssertEqual(metadata?.cwd, "/Users/test/workspace")
        XCTAssertEqual(metadata?.sessionName, "My Test Session")
    }
    
    func testLoadSessionMetadata_MalformedJSON() throws {
        let sessionId = "malformed-meta"
        let malformedJSON = "not json at all"
        
        let metadataURL = tempDirectory.appendingPathComponent("\(sessionId).json")
        try malformedJSON.data(using: .utf8)!.write(to: metadataURL)
        
        let metadata = try sessionStorage.getSessionMetadata(sessionId: sessionId)
        XCTAssertNil(metadata, "Should return nil for malformed JSON, not crash")
    }
    
    func testLoadSessionMetadata_NotFound() throws {
        let metadata = try sessionStorage.getSessionMetadata(sessionId: "nonexistent")
        XCTAssertNil(metadata)
    }
    
    // MARK: - Load Session Events Tests
    
    func testLoadSessionEvents_ValidEvents() throws {
        let sessionId = "events-test"
        let eventsContent = """
        {"type": "user_message", "content": "Hello"}
        {"type": "agent_message", "content": "Hi there"}
        {"type": "turn_end"}
        """
        
        // Create metadata
        let metadataJSON = """
        {"session_id": "\(sessionId)", "cwd": "/test"}
        """
        try metadataJSON.data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("\(sessionId).json"))
        
        // Create events
        let eventsURL = tempDirectory.appendingPathComponent("\(sessionId).jsonl")
        try eventsContent.data(using: .utf8)!.write(to: eventsURL)
        
        let events = sessionStorage.loadSessionEvents(sessionId: sessionId)
        XCTAssertNotNil(events)
        XCTAssertEqual(events?.count, 3)
    }
    
    func testLoadSessionEvents_SkipsInvalidLines() throws {
        let sessionId = "mixed-events"
        let eventsContent = """
        {"type": "user_message", "content": "Valid line 1"}
        this is not valid json
        {"type": "agent_message", "content": "Valid line 2"}
        { broken json {
        {"type": "turn_end"}
        """
        
        // Create events file
        let eventsURL = tempDirectory.appendingPathComponent("\(sessionId).jsonl")
        try eventsContent.data(using: .utf8)!.write(to: eventsURL)
        
        let events = sessionStorage.loadSessionEvents(sessionId: sessionId)
        XCTAssertNotNil(events)
        XCTAssertEqual(events?.count, 3, "Should have 3 valid events, skipping 2 invalid lines")
    }
    
    func testLoadSessionEvents_EmptyFile() throws {
        let sessionId = "empty-events"
        
        // Create empty events file
        let eventsURL = tempDirectory.appendingPathComponent("\(sessionId).jsonl")
        try "".data(using: .utf8)!.write(to: eventsURL)
        
        let events = sessionStorage.loadSessionEvents(sessionId: sessionId)
        XCTAssertNotNil(events)
        XCTAssertEqual(events?.count, 0)
    }
    
    func testLoadSessionEvents_FileNotFound() throws {
        let events = sessionStorage.loadSessionEvents(sessionId: "nonexistent")
        XCTAssertNil(events)
    }
    
    // MARK: - Load Session History Tests
    
    func testLoadSessionHistory_ValidSession() throws {
        let sessionId = "history-test"
        
        // Create metadata
        let metadataJSON = """
        {"session_id": "\(sessionId)", "cwd": "/test"}
        """
        try metadataJSON.data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("\(sessionId).json"))
        
        // Create events
        let eventsContent = """
        {"type": "user_message", "content": "Hello agent"}
        {"type": "agent_message", "content": "Hello! "}
        {"type": "agent_message", "content": "How can I help?"}
        {"type": "turn_end"}
        """
        let eventsURL = tempDirectory.appendingPathComponent("\(sessionId).jsonl")
        try eventsContent.data(using: .utf8)!.write(to: eventsURL)
        
        let messages = try sessionStorage.loadSessionHistory(sessionId: sessionId)
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, .user)
        XCTAssertEqual(messages[0].content, "Hello agent")
        XCTAssertEqual(messages[1].role, .assistant)
        XCTAssertEqual(messages[1].content, "Hello! How can I help?")
    }
    
    func testLoadSessionHistory_EmptySession() throws {
        let sessionId = "empty-history"
        
        // Create empty events file
        let eventsURL = tempDirectory.appendingPathComponent("\(sessionId).jsonl")
        try "".data(using: .utf8)!.write(to: eventsURL)
        
        let messages = try sessionStorage.loadSessionHistory(sessionId: sessionId)
        XCTAssertEqual(messages.count, 0, "Empty session should return empty array")
    }
    
    func testLoadSessionHistory_SkipsCorruptEvents() throws {
        let sessionId = "corrupt-history"
        
        // Create events with some corrupt lines
        let eventsContent = """
        {"type": "user_message", "content": "First message"}
        not valid json at all
        {"type": "agent_message", "content": "Response"}
        {"type": "turn_end"}
        {"type": "user_message", "content": "Second message"}
        { broken
        {"type": "agent_message", "content": "Another response"}
        {"type": "turn_end"}
        """
        let eventsURL = tempDirectory.appendingPathComponent("\(sessionId).jsonl")
        try eventsContent.data(using: .utf8)!.write(to: eventsURL)
        
        let messages = try sessionStorage.loadSessionHistory(sessionId: sessionId)
        XCTAssertEqual(messages.count, 4, "Should have 4 messages from valid events")
        XCTAssertEqual(messages[0].content, "First message")
        XCTAssertEqual(messages[1].content, "Response")
        XCTAssertEqual(messages[2].content, "Second message")
        XCTAssertEqual(messages[3].content, "Another response")
    }
    
    func testLoadSessionHistory_UnknownEventTypes() throws {
        let sessionId = "unknown-types"
        
        // Create events with unknown event types
        let eventsContent = """
        {"type": "user_message", "content": "Hello"}
        {"type": "some_future_event_type", "content": "Unknown"}
        {"type": "agent_message", "content": "Hi"}
        {"type": "another_unknown_type", "data": {"foo": "bar"}}
        {"type": "turn_end"}
        """
        let eventsURL = tempDirectory.appendingPathComponent("\(sessionId).jsonl")
        try eventsContent.data(using: .utf8)!.write(to: eventsURL)
        
        let messages = try sessionStorage.loadSessionHistory(sessionId: sessionId)
        XCTAssertEqual(messages.count, 2, "Should have 2 messages, unknown types ignored")
        XCTAssertEqual(messages[0].content, "Hello")
        XCTAssertEqual(messages[1].content, "Hi")
    }
    
    func testLoadSessionHistory_NilContent() throws {
        let sessionId = "nil-content"
        
        // Create events with nil/missing content
        let eventsContent = """
        {"type": "user_message", "content": "Valid user message"}
        {"type": "agent_message"}
        {"type": "turn_end"}
        {"type": "user_message"}
        {"type": "agent_message", "content": "Valid agent message"}
        {"type": "turn_end"}
        """
        let eventsURL = tempDirectory.appendingPathComponent("\(sessionId).jsonl")
        try eventsContent.data(using: .utf8)!.write(to: eventsURL)
        
        let messages = try sessionStorage.loadSessionHistory(sessionId: sessionId)
        // Should have 2 messages: first valid user message and last valid agent message
        // The user message with nil content is skipped, agent message with nil content contributes nothing
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].content, "Valid user message")
        XCTAssertEqual(messages[1].content, "Valid agent message")
    }
    
    func testLoadSessionHistory_SessionNotFound() throws {
        XCTAssertThrowsError(try sessionStorage.loadSessionHistory(sessionId: "nonexistent")) { error in
            if case SessionStorageError.sessionNotFound(let id) = error {
                XCTAssertEqual(id, "nonexistent")
            } else {
                XCTFail("Expected SessionStorageError.sessionNotFound, got \(error)")
            }
        }
    }
    
    // MARK: - List Sessions Tests
    
    func testListAllSessions_Mixed() throws {
        // Create valid session
        let validId = "valid-list-session"
        let validJSON = """
        {"session_id": "\(validId)", "cwd": "/valid/path"}
        """
        try validJSON.data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("\(validId).json"))
        
        // Create malformed session
        let malformedId = "malformed-list-session"
        try "not json".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("\(malformedId).json"))
        
        // Create another valid session
        let validId2 = "valid-list-session-2"
        let validJSON2 = """
        {"session_id": "\(validId2)", "cwd": "/another/path"}
        """
        try validJSON2.data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("\(validId2).json"))
        
        let sessions = sessionStorage.listAllSessions()
        
        // Should only return valid sessions
        XCTAssertEqual(sessions.count, 2)
        let sessionIds = sessions.map { $0.sessionId }
        XCTAssertTrue(sessionIds.contains(validId))
        XCTAssertTrue(sessionIds.contains(validId2))
        XCTAssertFalse(sessionIds.contains(malformedId))
    }
    
    // MARK: - Session Exists Tests
    
    func testSessionExists_Valid() throws {
        let sessionId = "exists-test"
        let metadataJSON = """
        {"session_id": "\(sessionId)", "cwd": "/test"}
        """
        try metadataJSON.data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("\(sessionId).json"))
        
        XCTAssertTrue(sessionStorage.sessionExists(sessionId: sessionId))
    }
    
    func testSessionExists_NotFound() throws {
        XCTAssertFalse(sessionStorage.sessionExists(sessionId: "nonexistent"))
    }
    
    func testSessionExists_Invalid() throws {
        let sessionId = "invalid-exists"
        try "not json".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("\(sessionId).json"))
        
        XCTAssertFalse(sessionStorage.sessionExists(sessionId: sessionId))
    }
}
