import Foundation

/// Types of events that can occur for an agent
public enum ActivityEventType: String, Codable, Sendable {
    /// A message from the agent or user
    case message
    /// A tool invocation
    case toolCall
    /// An error occurred
    case error
    /// Agent completed a task
    case complete
}

/// Represents a single activity event across any agent
public struct ActivityEvent: Identifiable, Sendable {
    /// Unique identifier for this event
    public let id: UUID
    /// ID of the agent that generated this event
    public let agentId: UUID
    /// Human-readable name of the agent
    public let agentName: String
    /// Type of event
    public let eventType: ActivityEventType
    /// Description of the event
    public let description: String
    /// When the event occurred
    public let timestamp: Date
    
    public init(
        id: UUID = UUID(),
        agentId: UUID,
        agentName: String,
        eventType: ActivityEventType,
        description: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.agentId = agentId
        self.agentName = agentName
        self.eventType = eventType
        self.description = description
        self.timestamp = timestamp
    }
}

extension ActivityEvent: Equatable {
    public static func == (lhs: ActivityEvent, rhs: ActivityEvent) -> Bool {
        lhs.id == rhs.id
    }
}

extension ActivityEvent: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
