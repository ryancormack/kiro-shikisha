import XCTest
@testable import KiroShikisha

final class ACPProtocolTests: XCTestCase {
    
    func testJSONRPCRequestEncoding() throws {
        struct TestParams: Codable, Sendable {
            let name: String
            let value: Int
        }
        
        let request = JSONRPCRequest(
            id: 1,
            method: "test.method",
            params: TestParams(name: "test", value: 42)
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("\"jsonrpc\":\"2.0\""))
        XCTAssertTrue(json.contains("\"id\":1"))
        XCTAssertTrue(json.contains("\"method\":\"test.method\""))
        XCTAssertTrue(json.contains("\"name\":\"test\""))
        XCTAssertTrue(json.contains("\"value\":42"))
    }
    
    func testJSONRPCRequestWithoutParams() throws {
        let request = JSONRPCRequest<String>(
            id: 2,
            method: "test.noparams",
            params: nil
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("\"jsonrpc\":\"2.0\""))
        XCTAssertTrue(json.contains("\"id\":2"))
        XCTAssertTrue(json.contains("\"method\":\"test.noparams\""))
        XCTAssertFalse(json.contains("\"params\""))
    }
    
    func testJSONRPCResponseDecoding() throws {
        let jsonString = """
        {"jsonrpc":"2.0","id":1,"result":{"status":"ok"}}
        """
        
        struct TestResult: Codable, Sendable {
            let status: String
        }
        
        let decoder = JSONDecoder()
        let data = jsonString.data(using: .utf8)!
        let response = try decoder.decode(JSONRPCResponse<TestResult>.self, from: data)
        
        XCTAssertEqual(response.jsonrpc, "2.0")
        XCTAssertEqual(response.id, 1)
        XCTAssertEqual(response.result?.status, "ok")
        XCTAssertNil(response.error)
    }
    
    func testJSONRPCErrorResponse() throws {
        let jsonString = """
        {"jsonrpc":"2.0","id":1,"error":{"code":-32601,"message":"Method not found"}}
        """
        
        struct EmptyResult: Codable, Sendable {}
        
        let decoder = JSONDecoder()
        let data = jsonString.data(using: .utf8)!
        let response = try decoder.decode(JSONRPCResponse<EmptyResult>.self, from: data)
        
        XCTAssertEqual(response.jsonrpc, "2.0")
        XCTAssertEqual(response.id, 1)
        XCTAssertNil(response.result)
        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, JSONRPCError.methodNotFound)
        XCTAssertEqual(response.error?.message, "Method not found")
    }
    
    func testJSONRPCNotificationEncoding() throws {
        struct NotifyParams: Codable, Sendable {
            let event: String
        }
        
        let notification = JSONRPCNotification(
            method: "session.update",
            params: NotifyParams(event: "started")
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("\"jsonrpc\":\"2.0\""))
        XCTAssertTrue(json.contains("\"method\":\"session.update\""))
        XCTAssertFalse(json.contains("\"id\""))
    }
    
    func testSessionPromptParamsEncoding() throws {
        // Test that prompt is encoded as a direct array, not wrapped in {"content": [...]}
        let params = SessionPromptParams(
            sessionId: "sess_abc123",
            content: [ContentBlock.text("Hello")]
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(params)
        let json = String(data: data, encoding: .utf8)!
        
        // Verify prompt is a direct array (contains "prompt":[) not nested (would be "prompt":{"content":[)
        XCTAssertTrue(json.contains("\"prompt\":["))
        XCTAssertFalse(json.contains("\"content\":["), "prompt should not be wrapped in a content object")
        XCTAssertTrue(json.contains("\"sessionId\":\"sess_abc123\""))
        XCTAssertTrue(json.contains("\"type\":\"text\""))
        XCTAssertTrue(json.contains("\"text\":\"Hello\""))
    }
}
