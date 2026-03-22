import XCTest
import ACPModel
@testable import KiroKantoku

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
    
    // MARK: - Image Content Tests
    
    func testImageContentEncoding() throws {
        let imageContent = ImageContent(data: "base64data==", mimeType: "image/png")
        let block = ContentBlock.image(imageContent)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(block)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("\"type\":\"image\""))
        XCTAssertTrue(json.contains("\"data\":\"base64data==\""))
        // Verify mimeType via round-trip decode since JSON may escape slashes
        let decoded = try JSONDecoder().decode(ContentBlock.self, from: data)
        if case .image(let img) = decoded {
            XCTAssertEqual(img.mimeType, "image/png")
            XCTAssertEqual(img.data, "base64data==")
        } else {
            XCTFail("Expected image content block")
        }
    }
    
    // MARK: - Cancel Notification Tests
    
    func testCancelNotificationEncoding() throws {
        let notification = CancelNotification(sessionId: SessionId(value: "sess_cancel_test"))
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(notification)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("\"sessionId\":\"sess_cancel_test\""))
    }
    
    // MARK: - Available Command Tests
    
    func testAvailableCommandProperties() throws {
        let cmd = AvailableCommand(name: "/help", description: "Shows help")
        XCTAssertEqual(cmd.name, "/help")
        XCTAssertEqual(cmd.description, "Shows help")
        XCTAssertNil(cmd.input)
    }
    
    // MARK: - Execute Slash Command JSON Format Tests
    
    func testExecuteSlashCommandJsonFormat() throws {
        // Reproduce the exact structure that ACPConnection.executeSlashCommand builds:
        // { "sessionId": "<id>", "command": { "command": "<name>", "args": {<args>} } }
        let sessionId = "sess_test123"
        let commandName = "model"
        let args: [String: String] = ["value": "gpt-4"]
        
        var argsObject: [String: JsonValue] = [:]
        for (key, value) in args {
            argsObject[key] = .string(value)
        }
        
        let commandObject: JsonValue = .object([
            "command": .string(commandName),
            "args": .object(argsObject)
        ])
        
        let paramsValue: JsonValue = .object([
            "sessionId": .string(sessionId),
            "command": commandObject
        ])
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(paramsValue)
        let json = String(data: data, encoding: .utf8)!
        
        // Verify the nested TuiCommand structure
        XCTAssertTrue(json.contains("\"sessionId\":\"sess_test123\""), "Should contain sessionId: \(json)")
        XCTAssertTrue(json.contains("\"command\":{"), "Should contain command object: \(json)")
        
        // Decode back to verify structure
        let decoded = try JSONDecoder().decode(JsonValue.self, from: data)
        guard case .object(let root) = decoded else {
            XCTFail("Expected root object"); return
        }
        XCTAssertEqual(root["sessionId"]?.stringValue, "sess_test123")
        
        guard case .object(let cmd) = root["command"] else {
            XCTFail("Expected command object"); return
        }
        XCTAssertEqual(cmd["command"]?.stringValue, "model")
        
        guard case .object(let decodedArgs) = cmd["args"] else {
            XCTFail("Expected args object"); return
        }
        XCTAssertEqual(decodedArgs["value"]?.stringValue, "gpt-4")
    }
    
    func testExecuteSlashCommandJsonFormatEmptyArgs() throws {
        // Test with no args - should produce {"command": "<name>", "args": {}}
        let commandObject: JsonValue = .object([
            "command": .string("clear"),
            "args": .object([:])
        ])
        
        let paramsValue: JsonValue = .object([
            "sessionId": .string("sess_abc"),
            "command": commandObject
        ])
        
        let data = try JSONEncoder().encode(paramsValue)
        let decoded = try JSONDecoder().decode(JsonValue.self, from: data)
        
        guard case .object(let root) = decoded,
              case .object(let cmd) = root["command"],
              case .object(let args) = cmd["args"] else {
            XCTFail("Expected nested command/args structure"); return
        }
        
        XCTAssertEqual(cmd["command"]?.stringValue, "clear")
        XCTAssertTrue(args.isEmpty, "Args should be empty")
    }
    
    func testExecuteSlashCommandStripsLeadingSlash() throws {
        // Reproduce the slash-stripping logic from executeSlashCommand
        let commandName = "/model"
        let name = commandName.hasPrefix("/") ? String(commandName.dropFirst()) : commandName
        XCTAssertEqual(name, "model")
        
        let commandNameNoSlash = "model"
        let name2 = commandNameNoSlash.hasPrefix("/") ? String(commandNameNoSlash.dropFirst()) : commandNameNoSlash
        XCTAssertEqual(name2, "model")
    }
    
    // MARK: - CommandOption Encoding/Decoding Tests
    
    func testCommandOptionEncodingDecodingRoundTrip() throws {
        let option = CommandOption(value: "gpt-4", label: "GPT-4", description: "OpenAI GPT-4", group: "OpenAI")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(option)
        let decoded = try JSONDecoder().decode(CommandOption.self, from: data)
        
        XCTAssertEqual(decoded.value, "gpt-4")
        XCTAssertEqual(decoded.label, "GPT-4")
        XCTAssertEqual(decoded.description, "OpenAI GPT-4")
        XCTAssertEqual(decoded.group, "OpenAI")
        XCTAssertEqual(decoded.id, "gpt-4") // id is derived from value
    }
    
    func testCommandOptionWithNilOptionals() throws {
        let option = CommandOption(value: "claude-3", label: "Claude 3")
        
        let data = try JSONEncoder().encode(option)
        let decoded = try JSONDecoder().decode(CommandOption.self, from: data)
        
        XCTAssertEqual(decoded.value, "claude-3")
        XCTAssertEqual(decoded.label, "Claude 3")
        XCTAssertNil(decoded.description)
        XCTAssertNil(decoded.group)
    }
    
    func testCommandOptionDecodingFromJson() throws {
        let json = """
        {"value":"test-val","label":"Test Label","description":"A description","group":"TestGroup"}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(CommandOption.self, from: data)
        
        XCTAssertEqual(decoded.value, "test-val")
        XCTAssertEqual(decoded.label, "Test Label")
        XCTAssertEqual(decoded.description, "A description")
        XCTAssertEqual(decoded.group, "TestGroup")
    }
    
    // MARK: - CommandOptionsResponse Encoding/Decoding Tests
    
    func testCommandOptionsResponseEncodingDecodingRoundTrip() throws {
        let options = [
            CommandOption(value: "opt1", label: "Option 1", description: "First", group: "A"),
            CommandOption(value: "opt2", label: "Option 2", description: nil, group: nil)
        ]
        let response = CommandOptionsResponse(options: options, hasMore: true)
        
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(CommandOptionsResponse.self, from: data)
        
        XCTAssertEqual(decoded.options.count, 2)
        XCTAssertEqual(decoded.options[0].value, "opt1")
        XCTAssertEqual(decoded.options[0].label, "Option 1")
        XCTAssertEqual(decoded.options[1].value, "opt2")
        XCTAssertTrue(decoded.hasMore)
    }
    
    func testCommandOptionsResponseDefaultHasMore() throws {
        let response = CommandOptionsResponse(options: [])
        
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(CommandOptionsResponse.self, from: data)
        
        XCTAssertTrue(decoded.options.isEmpty)
        XCTAssertFalse(decoded.hasMore)
    }
    
    func testCommandOptionsResponseDecodingFromJson() throws {
        let json = """
        {"options":[{"value":"v1","label":"L1"},{"value":"v2","label":"L2","description":"D2","group":"G2"}],"hasMore":false}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(CommandOptionsResponse.self, from: data)
        
        XCTAssertEqual(decoded.options.count, 2)
        XCTAssertEqual(decoded.options[0].value, "v1")
        XCTAssertNil(decoded.options[0].description)
        XCTAssertEqual(decoded.options[1].group, "G2")
        XCTAssertFalse(decoded.hasMore)
    }
    
    // MARK: - KiroAvailableCommand Meta Tests
    
    func testKiroAvailableCommandWithMetaInputType() throws {
        let meta: JsonValue = .object([
            "inputType": .string("selection"),
            "optionsMethod": .string("_kiro.dev/commands/options"),
            "local": .bool(false),
            "hint": .string("Select a model")
        ])
        let cmd = KiroAvailableCommand(name: "model", description: "Switch model", meta: meta)
        
        let data = try JSONEncoder().encode(cmd)
        let decoded = try JSONDecoder().decode(KiroAvailableCommand.self, from: data)
        
        XCTAssertEqual(decoded.name, "model")
        XCTAssertEqual(decoded.description, "Switch model")
        XCTAssertNotNil(decoded.meta)
        
        guard let metaObj = decoded.meta?.objectValue else {
            XCTFail("Expected meta to be an object"); return
        }
        XCTAssertEqual(metaObj["inputType"]?.stringValue, "selection")
        XCTAssertEqual(metaObj["optionsMethod"]?.stringValue, "_kiro.dev/commands/options")
        XCTAssertEqual(metaObj["local"]?.boolValue, false)
        XCTAssertEqual(metaObj["hint"]?.stringValue, "Select a model")
    }
    
    func testKiroAvailableCommandWithLocalMeta() throws {
        let meta: JsonValue = .object([
            "local": .bool(true)
        ])
        let cmd = KiroAvailableCommand(name: "quit", description: "Quit the app", meta: meta)
        
        let data = try JSONEncoder().encode(cmd)
        let decoded = try JSONDecoder().decode(KiroAvailableCommand.self, from: data)
        
        XCTAssertEqual(decoded.name, "quit")
        XCTAssertEqual(decoded.meta?.objectValue?["local"]?.boolValue, true)
    }
    
    func testKiroAvailableCommandWithPanelMeta() throws {
        let meta: JsonValue = .object([
            "inputType": .string("panel")
        ])
        let cmd = KiroAvailableCommand(name: "context", description: "Show context", meta: meta)
        
        let data = try JSONEncoder().encode(cmd)
        let decoded = try JSONDecoder().decode(KiroAvailableCommand.self, from: data)
        
        XCTAssertEqual(decoded.meta?.objectValue?["inputType"]?.stringValue, "panel")
    }
    
    func testKiroAvailableCommandWithNilMeta() throws {
        let cmd = KiroAvailableCommand(name: "help", description: "Show help")
        
        let data = try JSONEncoder().encode(cmd)
        let decoded = try JSONDecoder().decode(KiroAvailableCommand.self, from: data)
        
        XCTAssertEqual(decoded.name, "help")
        XCTAssertNil(decoded.meta)
    }
    
    func testKiroCommandsAvailableParamsRoundTrip() throws {
        let commands = [
            KiroAvailableCommand(name: "model", description: "Switch model", meta: .object([
                "inputType": .string("selection"),
                "optionsMethod": .string("_kiro.dev/commands/options")
            ])),
            KiroAvailableCommand(name: "clear", description: "Clear chat", meta: nil)
        ]
        let params = KiroCommandsAvailableParams(sessionId: "sess_xyz", commands: commands)
        
        let data = try JSONEncoder().encode(params)
        let decoded = try JSONDecoder().decode(KiroCommandsAvailableParams.self, from: data)
        
        XCTAssertEqual(decoded.sessionId, "sess_xyz")
        XCTAssertEqual(decoded.commands.count, 2)
        XCTAssertEqual(decoded.commands[0].name, "model")
        XCTAssertNotNil(decoded.commands[0].meta)
        XCTAssertEqual(decoded.commands[1].name, "clear")
        XCTAssertNil(decoded.commands[1].meta)
    }
    
    // MARK: - Kiro Extension Notification Model Tests
    
    func testKiroMetadataParamsRoundTrip() throws {
        let params = KiroMetadataParams(sessionId: "sess_meta", contextUsagePercentage: 42.5)
        
        let data = try JSONEncoder().encode(params)
        let decoded = try JSONDecoder().decode(KiroMetadataParams.self, from: data)
        
        XCTAssertEqual(decoded.sessionId, "sess_meta")
        XCTAssertEqual(decoded.contextUsagePercentage, 42.5, accuracy: 0.001)
    }
    
    func testKiroAgentSwitchedParamsRoundTrip() throws {
        let params = KiroAgentSwitchedParams(
            sessionId: "sess_switch",
            agentName: "CodeAgent",
            previousAgentName: "ChatAgent",
            welcomeMessage: "Hello from CodeAgent!"
        )
        
        let data = try JSONEncoder().encode(params)
        let decoded = try JSONDecoder().decode(KiroAgentSwitchedParams.self, from: data)
        
        XCTAssertEqual(decoded.sessionId, "sess_switch")
        XCTAssertEqual(decoded.agentName, "CodeAgent")
        XCTAssertEqual(decoded.previousAgentName, "ChatAgent")
        XCTAssertEqual(decoded.welcomeMessage, "Hello from CodeAgent!")
    }
    
    func testKiroAgentSwitchedParamsNilWelcomeMessage() throws {
        let params = KiroAgentSwitchedParams(
            sessionId: "sess_switch2",
            agentName: "Agent2",
            previousAgentName: "Agent1"
        )
        
        let data = try JSONEncoder().encode(params)
        let decoded = try JSONDecoder().decode(KiroAgentSwitchedParams.self, from: data)
        
        XCTAssertEqual(decoded.agentName, "Agent2")
        XCTAssertNil(decoded.welcomeMessage)
    }
    
    func testKiroToolCallChunkUpdateRoundTrip() throws {
        let update = KiroToolCallChunkUpdate(
            sessionUpdate: "tool_call_chunk",
            toolCallId: "tc_abc",
            title: "Reading file",
            kind: "read"
        )
        
        let data = try JSONEncoder().encode(update)
        let decoded = try JSONDecoder().decode(KiroToolCallChunkUpdate.self, from: data)
        
        XCTAssertEqual(decoded.sessionUpdate, "tool_call_chunk")
        XCTAssertEqual(decoded.toolCallId, "tc_abc")
        XCTAssertEqual(decoded.title, "Reading file")
        XCTAssertEqual(decoded.kind, "read")
    }
    
    func testKiroCompactionStatusParamsRoundTrip() throws {
        let params = KiroCompactionStatusParams(message: "Compacting context...")
        
        let data = try JSONEncoder().encode(params)
        let decoded = try JSONDecoder().decode(KiroCompactionStatusParams.self, from: data)
        
        XCTAssertEqual(decoded.message, "Compacting context...")
    }
    
    func testKiroClearStatusParamsRoundTrip() throws {
        let params = KiroClearStatusParams(message: "Clearing history...")
        
        let data = try JSONEncoder().encode(params)
        let decoded = try JSONDecoder().decode(KiroClearStatusParams.self, from: data)
        
        XCTAssertEqual(decoded.message, "Clearing history...")
    }
    
    func testKiroMcpOAuthRequestParamsRoundTrip() throws {
        let params = KiroMcpOAuthRequestParams(url: "https://example.com/oauth/authorize?state=abc123")
        
        let data = try JSONEncoder().encode(params)
        let decoded = try JSONDecoder().decode(KiroMcpOAuthRequestParams.self, from: data)
        
        XCTAssertEqual(decoded.url, "https://example.com/oauth/authorize?state=abc123")
    }
}
