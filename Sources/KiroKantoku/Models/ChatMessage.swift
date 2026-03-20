import Foundation

/// Role of a message in a chat conversation
public enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

/// A message in a chat conversation with an agent
public struct ChatMessage: Identifiable, Equatable, Sendable, Codable {
    /// Unique identifier for this message
    public let id: UUID
    /// Role of the message sender
    public let role: MessageRole
    /// Text content of the message
    public var content: String
    /// When this message was created
    public let timestamp: Date
    /// IDs of tool calls associated with this message (for assistant messages)
    public var toolCallIds: [String]?
    
    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        toolCallIds: [String]? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.toolCallIds = toolCallIds
    }
}
