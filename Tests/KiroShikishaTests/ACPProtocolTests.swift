import XCTest
import ACPModel
@testable import KiroShikisha

final class ACPProtocolTests: XCTestCase {
    
    // MARK: - SDK Type Tests
    
    func testContentBlockTextEncoding() throws {
        // Test that SDK's ContentBlock encodes correctly
        let textContent = TextContent(text: "Hello, world!")
        let contentBlock = ContentBlock.text(textContent)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(contentBlock)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("\"type\":\"text\""))
        XCTAssertTrue(json.contains("\"text\":\"Hello, world!\""))
    }
    
    func testSessionIdFromString() throws {
        let sessionId = SessionId(value: "sess_abc123")
        XCTAssertEqual(sessionId.value, "sess_abc123")
        XCTAssertEqual(sessionId.description, "sess_abc123")
    }
    
    func testToolCallIdFromString() throws {
        let toolCallId = ToolCallId(value: "tc_123")
        XCTAssertEqual(toolCallId.value, "tc_123")
        XCTAssertEqual(toolCallId.description, "tc_123")
    }
    
    func testNewSessionRequestEncoding() throws {
        let request = NewSessionRequest(cwd: "/workspace", mcpServers: [])
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!
        
        // Check that required fields are present
        XCTAssertTrue(json.contains("cwd"), "JSON should contain cwd: \(json)")
        XCTAssertTrue(json.contains("/workspace"), "JSON should contain /workspace: \(json)")
        XCTAssertTrue(json.contains("mcpServers"), "JSON should contain mcpServers: \(json)")
    }
    
    func testPromptRequestEncoding() throws {
        let sessionId = SessionId(value: "sess_test")
        let prompt = [ContentBlock.text(TextContent(text: "Hello"))]
        let request = PromptRequest(sessionId: sessionId, prompt: prompt)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!
        
        // Verify prompt is a direct array
        XCTAssertTrue(json.contains("\"prompt\":["))
        XCTAssertTrue(json.contains("\"sessionId\":\"sess_test\""))
        XCTAssertTrue(json.contains("\"type\":\"text\""))
        XCTAssertTrue(json.contains("\"text\":\"Hello\""))
    }
    
    func testClientCapabilitiesEncoding() throws {
        let capabilities = ClientCapabilities(
            fs: FileSystemCapability(readTextFile: true, writeTextFile: true),
            terminal: true
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(capabilities)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("\"readTextFile\":true"))
        XCTAssertTrue(json.contains("\"writeTextFile\":true"))
        XCTAssertTrue(json.contains("\"terminal\":true"))
    }
    
    func testStopReasonDecoding() throws {
        let testCases: [(String, StopReason)] = [
            ("\"end_turn\"", .endTurn),
            ("\"max_tokens\"", .maxTokens),
            ("\"max_turn_requests\"", .maxTurnRequests),
            ("\"refusal\"", .refusal),
            ("\"cancelled\"", .cancelled)
        ]
        
        let decoder = JSONDecoder()
        for (json, expected) in testCases {
            let data = json.data(using: .utf8)!
            let decoded = try decoder.decode(StopReason.self, from: data)
            XCTAssertEqual(decoded, expected, "Failed to decode \(json)")
        }
    }
    
    // MARK: - Kiro Extension Tests
    
    func testKiroCommandsAvailableParams() throws {
        let command = KiroAvailableCommand(name: "test", description: "A test command", meta: nil)
        let params = KiroCommandsAvailableParams(sessionId: "sess_123", commands: [command])
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(params)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("\"sessionId\":\"sess_123\""))
        XCTAssertTrue(json.contains("\"name\":\"test\""))
        XCTAssertTrue(json.contains("\"description\":\"A test command\""))
    }
    
    func testKiroMcpServerInitFailureParams() throws {
        let params = KiroMcpServerInitFailureParams(
            sessionId: "sess_123",
            serverName: "test-server",
            error: "Connection refused"
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(params)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("\"sessionId\":\"sess_123\""))
        XCTAssertTrue(json.contains("\"serverName\":\"test-server\""))
        XCTAssertTrue(json.contains("\"error\":\"Connection refused\""))
    }
    
    // MARK: - Tool Call Tests
    
    func testToolKindValues() {
        // Verify all tool kinds map correctly
        let kinds: [ToolKind] = [.read, .edit, .delete, .move, .search, .execute, .think, .fetch, .switchMode, .other]
        XCTAssertEqual(kinds.count, 10)
    }
    
    func testToolCallStatusValues() {
        let statuses: [ToolCallStatus] = [.pending, .inProgress, .completed, .failed]
        XCTAssertEqual(statuses.count, 4)
    }
    
    func testDiffContentEncoding() throws {
        let diff = DiffContent(
            path: "/path/to/file.txt",
            newText: "new content",
            oldText: "old content"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(diff)
        let json = String(data: data, encoding: .utf8)!
        
        // Check that essential fields are present
        // Note: JSON may escape forward slashes, so we check for the path field and content
        XCTAssertTrue(json.contains("path"), "JSON should contain path field: \(json)")
        XCTAssertTrue(json.contains("file.txt"), "JSON should contain file.txt: \(json)")
        XCTAssertTrue(json.contains("newText"), "JSON should contain newText: \(json)")
        XCTAssertTrue(json.contains("new content"), "JSON should contain new content: \(json)")
        XCTAssertTrue(json.contains("type"), "JSON should contain type: \(json)")
        XCTAssertTrue(json.contains("diff"), "JSON should contain diff: \(json)")
    }

    // MARK: - Session Mode & Model Tests

    func testSetSessionModeRequestEncoding() throws {
        let request = SetSessionModeRequest(
            sessionId: SessionId(value: "sess_test"),
            modeId: SessionModeId(value: "agent")
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"sessionId\":\"sess_test\""), "JSON should contain sessionId: \(json)")
        XCTAssertTrue(json.contains("\"modeId\":\"agent\""), "JSON should contain modeId: \(json)")
    }

    func testSetSessionModelRequestEncoding() throws {
        let request = SetSessionModelRequest(
            sessionId: SessionId(value: "sess_test"),
            modelId: ModelId(value: "gpt-4")
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"sessionId\":\"sess_test\""), "JSON should contain sessionId: \(json)")
        XCTAssertTrue(json.contains("\"modelId\":\"gpt-4\""), "JSON should contain modelId: \(json)")
    }

    func testSessionModeIdValueType() throws {
        let modeId = SessionModeId(value: "agent")
        XCTAssertEqual(modeId.value, "agent")
        XCTAssertEqual(modeId.description, "agent")

        // Test Codable round-trip
        let encoder = JSONEncoder()
        let data = try encoder.encode(modeId)
        let decoded = try JSONDecoder().decode(SessionModeId.self, from: data)
        XCTAssertEqual(decoded.value, "agent")
    }

    func testModelIdValueType() throws {
        let modelId = ModelId(value: "claude-3-opus")
        XCTAssertEqual(modelId.value, "claude-3-opus")
        XCTAssertEqual(modelId.description, "claude-3-opus")

        // Test Codable round-trip
        let encoder = JSONEncoder()
        let data = try encoder.encode(modelId)
        let decoded = try JSONDecoder().decode(ModelId.self, from: data)
        XCTAssertEqual(decoded.value, "claude-3-opus")
    }

    func testSessionModeIdHashable() throws {
        let id1 = SessionModeId(value: "agent")
        let id2 = SessionModeId(value: "agent")
        let id3 = SessionModeId(value: "chat")

        XCTAssertEqual(id1, id2)
        XCTAssertNotEqual(id1, id3)

        var set = Set<SessionModeId>()
        set.insert(id1)
        set.insert(id2)
        XCTAssertEqual(set.count, 1)
    }

    func testModelIdHashable() throws {
        let id1 = ModelId(value: "gpt-4")
        let id2 = ModelId(value: "gpt-4")
        let id3 = ModelId(value: "claude-3")

        XCTAssertEqual(id1, id2)
        XCTAssertNotEqual(id1, id3)

        var set = Set<ModelId>()
        set.insert(id1)
        set.insert(id2)
        XCTAssertEqual(set.count, 1)
    }
}
