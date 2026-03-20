import XCTest
@testable import KiroKantoku

final class WorkspaceTests: XCTestCase {
    
    // MARK: - Workspace Tests
    
    func testWorkspaceCreation() throws {
        let path = URL(fileURLWithPath: "/Users/test/projects/myproject")
        let workspace = Workspace(
            name: "MyProject",
            path: path
        )
        
        XCTAssertEqual(workspace.name, "MyProject")
        XCTAssertEqual(workspace.path, path)
        XCTAssertNil(workspace.gitRepository)
        XCTAssertNil(workspace.gitBranch)
        XCTAssertNil(workspace.gitWorktreePath)
        XCTAssertNil(workspace.sourceWorkspaceId)
    }
    
    func testWorkspaceWithGitProperties() throws {
        let path = URL(fileURLWithPath: "/Users/test/projects/myrepo")
        let gitRepo = URL(string: "https://github.com/user/repo.git")!
        let worktreePath = URL(fileURLWithPath: "/Users/test/projects/myrepo-feature")
        let sourceId = UUID()
        
        let workspace = Workspace(
            name: "MyRepo",
            path: path,
            gitRepository: gitRepo,
            gitBranch: "feature-branch",
            gitWorktreePath: worktreePath,
            sourceWorkspaceId: sourceId
        )
        
        XCTAssertEqual(workspace.name, "MyRepo")
        XCTAssertEqual(workspace.path, path)
        XCTAssertEqual(workspace.gitRepository, gitRepo)
        XCTAssertEqual(workspace.gitBranch, "feature-branch")
        XCTAssertEqual(workspace.gitWorktreePath, worktreePath)
        XCTAssertEqual(workspace.sourceWorkspaceId, sourceId)
    }
    
    func testWorkspaceEncodingDecoding() throws {
        let path = URL(fileURLWithPath: "/Users/test/projects/testproject")
        let gitRepo = URL(string: "https://github.com/test/repo.git")!
        let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)
        
        let workspace = Workspace(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            name: "TestProject",
            path: path,
            gitRepository: gitRepo,
            gitBranch: "main",
            createdAt: fixedDate,
            lastAccessedAt: fixedDate
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(workspace)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Workspace.self, from: data)
        
        XCTAssertEqual(decoded.id, workspace.id)
        XCTAssertEqual(decoded.name, workspace.name)
        XCTAssertEqual(decoded.path, workspace.path)
        XCTAssertEqual(decoded.gitRepository, workspace.gitRepository)
        XCTAssertEqual(decoded.gitBranch, workspace.gitBranch)
        XCTAssertEqual(decoded.createdAt, workspace.createdAt)
        XCTAssertEqual(decoded.lastAccessedAt, workspace.lastAccessedAt)
    }
    
    func testWorkspaceHashable() throws {
        // Use fixed dates to ensure equality
        let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)
        
        let workspace1 = Workspace(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Test",
            path: URL(fileURLWithPath: "/test"),
            createdAt: fixedDate,
            lastAccessedAt: fixedDate
        )
        let workspace2 = Workspace(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Test",
            path: URL(fileURLWithPath: "/test"),
            createdAt: fixedDate,
            lastAccessedAt: fixedDate
        )
        let workspace3 = Workspace(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Other",
            path: URL(fileURLWithPath: "/other"),
            createdAt: fixedDate,
            lastAccessedAt: fixedDate
        )
        
        XCTAssertEqual(workspace1, workspace2)
        XCTAssertNotEqual(workspace1, workspace3)
        
        var workspaceSet: Set<Workspace> = []
        workspaceSet.insert(workspace1)
        workspaceSet.insert(workspace2)
        XCTAssertEqual(workspaceSet.count, 1)
    }
    
    // MARK: - ChatMessage Tests
    
    func testChatMessageCreation() throws {
        let userMessage = ChatMessage(
            role: .user,
            content: "Hello, agent!"
        )
        XCTAssertEqual(userMessage.role, .user)
        XCTAssertEqual(userMessage.content, "Hello, agent!")
        XCTAssertNil(userMessage.toolCallIds)
        
        let assistantMessage = ChatMessage(
            role: .assistant,
            content: "Hello! How can I help?",
            toolCallIds: ["tool-1", "tool-2"]
        )
        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertEqual(assistantMessage.content, "Hello! How can I help?")
        XCTAssertEqual(assistantMessage.toolCallIds, ["tool-1", "tool-2"])
        
        let systemMessage = ChatMessage(
            role: .system,
            content: "You are a helpful assistant."
        )
        XCTAssertEqual(systemMessage.role, .system)
        XCTAssertEqual(systemMessage.content, "You are a helpful assistant.")
    }
    
    func testChatMessageEncodingDecoding() throws {
        let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)
        let message = ChatMessage(
            id: UUID(uuidString: "abcdefab-1234-5678-9012-abcdefabcdef")!,
            role: .assistant,
            content: "Test response",
            timestamp: fixedDate,
            toolCallIds: ["call-123"]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ChatMessage.self, from: data)
        
        XCTAssertEqual(decoded.id, message.id)
        XCTAssertEqual(decoded.role, message.role)
        XCTAssertEqual(decoded.content, message.content)
        XCTAssertEqual(decoded.timestamp, message.timestamp)
        XCTAssertEqual(decoded.toolCallIds, message.toolCallIds)
    }
    
    func testMessageRoleValues() throws {
        XCTAssertEqual(MessageRole.user.rawValue, "user")
        XCTAssertEqual(MessageRole.assistant.rawValue, "assistant")
        XCTAssertEqual(MessageRole.system.rawValue, "system")
    }
    
    // MARK: - SessionMetadata Tests
    
    func testSessionMetadataDecoding() throws {
        let jsonString = """
        {
            "session_id": "abc123-session",
            "cwd": "/Users/test/projects/myproject"
        }
        """
        
        let decoder = JSONDecoder()
        let data = jsonString.data(using: .utf8)!
        let metadata = try decoder.decode(SessionMetadata.self, from: data)
        
        XCTAssertEqual(metadata.sessionId, "abc123-session")
        XCTAssertEqual(metadata.cwd, "/Users/test/projects/myproject")
        XCTAssertNil(metadata.createdAt)
        XCTAssertNil(metadata.lastModified)
    }
    
    func testSessionMetadataWithDates() throws {
        // Test with Unix timestamps
        let jsonWithTimestamp = """
        {
            "session_id": "session-with-dates",
            "cwd": "/Users/test/workspace",
            "created_at": 1700000000.0,
            "last_modified": 1700001000.0
        }
        """
        
        let decoder = JSONDecoder()
        let data = jsonWithTimestamp.data(using: .utf8)!
        let metadata = try decoder.decode(SessionMetadata.self, from: data)
        
        XCTAssertEqual(metadata.sessionId, "session-with-dates")
        XCTAssertEqual(metadata.cwd, "/Users/test/workspace")
        XCTAssertNotNil(metadata.createdAt)
        XCTAssertNotNil(metadata.lastModified)
        
        // Verify timestamps are parsed correctly
        XCTAssertEqual(metadata.createdAt?.timeIntervalSince1970, 1700000000.0)
        XCTAssertEqual(metadata.lastModified?.timeIntervalSince1970, 1700001000.0)
    }
    
    func testSessionMetadataWithISO8601Dates() throws {
        let jsonWithISO = """
        {
            "session_id": "session-iso-dates",
            "cwd": "/workspace",
            "created_at": "2024-01-15T10:30:00Z"
        }
        """
        
        let decoder = JSONDecoder()
        let data = jsonWithISO.data(using: .utf8)!
        let metadata = try decoder.decode(SessionMetadata.self, from: data)
        
        XCTAssertEqual(metadata.sessionId, "session-iso-dates")
        XCTAssertNotNil(metadata.createdAt)
    }
    
    func testSessionMetadataIdentifiable() throws {
        let metadata = SessionMetadata(
            sessionId: "test-session-id",
            cwd: "/test"
        )
        
        XCTAssertEqual(metadata.id, "test-session-id")
        XCTAssertEqual(metadata.id, metadata.sessionId)
    }
    
    func testSessionMetadataEncoding() throws {
        let metadata = SessionMetadata(
            sessionId: "encode-test",
            cwd: "/test/path",
            createdAt: Date(timeIntervalSince1970: 1700000000),
            lastModified: Date(timeIntervalSince1970: 1700001000)
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("\"session_id\":\"encode-test\""))
        // Path may be escaped as \/test\/path or /test/path depending on encoder
        XCTAssertTrue(json.contains("\"cwd\":") && (json.contains("/test/path") || json.contains("\\/test\\/path")))
    }
}
