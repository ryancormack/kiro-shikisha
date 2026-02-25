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

// MARK: - Tool Call Update

/// Update to an existing tool call
public struct ToolCallUpdate: Codable, Sendable {
    /// Type discriminator
    public let type: SessionUpdateType
    /// ID of the tool call being updated
    public let toolCallId: String
    /// New status
    public let status: ToolCallStatus
    /// Updated content
    public let content: String?
    
    public init(toolCallId: String, status: ToolCallStatus, content: String? = nil) {
        self.type = .toolCallUpdate
        self.toolCallId = toolCallId
        self.status = status
        self.content = content
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
