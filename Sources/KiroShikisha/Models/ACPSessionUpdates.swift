import Foundation

/// ACP session update types for streaming agent responses

// MARK: - Session Update Notification

/// Type of session update
public enum SessionUpdateType: String, Codable, Sendable {
    case agentMessageChunk
    case toolCall
    case toolCallUpdate
    case turnEnd
}

/// Notification sent when a session update occurs
public struct SessionUpdateNotification: Codable, Sendable {
    /// Session ID this update belongs to
    public let sessionId: String
    /// The update payload
    public let update: SessionUpdate
    
    public init(sessionId: String, update: SessionUpdate) {
        self.sessionId = sessionId
        self.update = update
    }
}

/// Union type for all session updates
public enum SessionUpdate: Codable, Sendable {
    case agentMessageChunk(AgentMessageChunk)
    case toolCall(ToolCall)
    case toolCallUpdate(ToolCallUpdate)
    case turnEnd(TurnEnd)
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(SessionUpdateType.self, forKey: .type)
        
        switch type {
        case .agentMessageChunk:
            self = .agentMessageChunk(try AgentMessageChunk(from: decoder))
        case .toolCall:
            self = .toolCall(try ToolCall(from: decoder))
        case .toolCallUpdate:
            self = .toolCallUpdate(try ToolCallUpdate(from: decoder))
        case .turnEnd:
            self = .turnEnd(try TurnEnd(from: decoder))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .agentMessageChunk(let chunk):
            try chunk.encode(to: encoder)
        case .toolCall(let call):
            try call.encode(to: encoder)
        case .toolCallUpdate(let update):
            try update.encode(to: encoder)
        case .turnEnd(let end):
            try end.encode(to: encoder)
        }
    }
}

// MARK: - Agent Message Chunk

/// Streaming text chunk from the agent
public struct AgentMessageChunk: Codable, Sendable {
    /// Type discriminator
    public let type: SessionUpdateType
    /// Content block containing the text chunk
    public let content: ContentBlock
    
    public init(content: ContentBlock) {
        self.type = .agentMessageChunk
        self.content = content
    }
}

// MARK: - Tool Call

/// Kind of tool operation
public enum ToolCallKind: String, Codable, Sendable {
    case read
    case edit
    case delete
    case move
    case search
    case execute
    case think
    case fetch
    case other
}

/// Status of a tool call
public enum ToolCallStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case completed
    case failed
}

/// A tool invocation by the agent
public struct ToolCall: Codable, Sendable {
    /// Type discriminator
    public let type: SessionUpdateType
    /// Unique identifier for this tool call
    public let toolCallId: String
    /// Human-readable title describing the operation
    public let title: String
    /// Kind of tool operation
    public let kind: ToolCallKind
    /// Current status
    public let status: ToolCallStatus
    /// Optional content describing the operation
    public let content: String?
    /// Raw JSON input to the tool
    public let rawInput: JSONValue?
    /// Raw JSON output from the tool
    public let rawOutput: JSONValue?
    
    public init(
        toolCallId: String,
        title: String,
        kind: ToolCallKind,
        status: ToolCallStatus,
        content: String? = nil,
        rawInput: JSONValue? = nil,
        rawOutput: JSONValue? = nil
    ) {
        self.type = .toolCall
        self.toolCallId = toolCallId
        self.title = title
        self.kind = kind
        self.status = status
        self.content = content
        self.rawInput = rawInput
        self.rawOutput = rawOutput
    }
}

// MARK: - Tool Call Content Types

/// Content type discriminator for tool call content
public enum ToolCallContentType: String, Codable, Sendable {
    case content
    case diff
    case terminal
}

/// Base protocol for tool call content
public enum ToolCallContent: Codable, Sendable {
    /// Text or image content
    case content(TextContent)
    /// Diff content showing file changes
    case diff(DiffContent)
    /// Terminal output content
    case terminal(TerminalContent)
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ToolCallContentType.self, forKey: .type)
        
        switch type {
        case .content:
            self = .content(try TextContent(from: decoder))
        case .diff:
            self = .diff(try DiffContent(from: decoder))
        case .terminal:
            self = .terminal(try TerminalContent(from: decoder))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .content(let textContent):
            try textContent.encode(to: encoder)
        case .diff(let diffContent):
            try diffContent.encode(to: encoder)
        case .terminal(let terminalContent):
            try terminalContent.encode(to: encoder)
        }
    }
}

/// Text content for tool calls
public struct TextContent: Codable, Sendable {
    public let type: ToolCallContentType
    public let text: String?
    
    public init(text: String?) {
        self.type = .content
        self.text = text
    }
}

/// Diff content showing file changes
public struct DiffContent: Codable, Sendable {
    public let type: ToolCallContentType
    /// Path to the file being changed
    public let path: String
    /// Original text before the change (nil for new files)
    public let oldText: String?
    /// New text after the change
    public let newText: String
    
    public init(path: String, oldText: String?, newText: String) {
        self.type = .diff
        self.path = path
        self.oldText = oldText
        self.newText = newText
    }
}

/// Terminal output content
public struct TerminalContent: Codable, Sendable {
    public let type: ToolCallContentType
    /// Terminal session identifier
    public let terminalId: String
    
    public init(terminalId: String) {
        self.type = .terminal
        self.terminalId = terminalId
    }
}

// MARK: - Tool Call Update

/// Update to an existing tool call
public struct ToolCallUpdate: Codable, Sendable {
    /// Type discriminator
    public let type: SessionUpdateType
    /// ID of the tool call being updated
    public let toolCallId: String
    /// New status
    public let status: ToolCallStatus
    /// Updated string content (legacy)
    public let content: String?
    /// Structured tool call content
    public let toolContent: ToolCallContent?
    
    private enum CodingKeys: String, CodingKey {
        case type
        case toolCallId
        case status
        case content
        case toolContent
    }
    
    public init(toolCallId: String, status: ToolCallStatus, content: String? = nil, toolContent: ToolCallContent? = nil) {
        self.type = .toolCallUpdate
        self.toolCallId = toolCallId
        self.status = status
        self.content = content
        self.toolContent = toolContent
    }
}

// MARK: - Turn End

/// Reason why an agent turn ended
public enum TurnEndReason: String, Codable, Sendable {
    case endTurn
    case maxTurns
    case cancelled
    case error
}

/// Notification that the agent's turn has ended
public struct TurnEnd: Codable, Sendable {
    /// Type discriminator
    public let type: SessionUpdateType
    /// Reason the turn ended
    public let reason: TurnEndReason
    
    public init(reason: TurnEndReason) {
        self.type = .turnEnd
        self.reason = reason
    }
}
