import Foundation
import ACPModel
#if canImport(Observation)
import Observation
#endif

/// Current operational status of an agent
public enum AgentStatus: String, Codable, Sendable {
    /// Agent is idle, not processing any requests
    case idle
    /// Agent is connecting to the ACP process
    case connecting
    /// Agent is actively processing a request
    case active
    /// Agent encountered an error
    case error
}

/// An AI agent operating on a workspace
/// Note: ACPConnection is managed separately by AgentManager to avoid circular dependencies
#if canImport(Observation)
@Observable
@MainActor
public final class Agent: Identifiable {
    /// Unique identifier for this agent
    public let id: UUID
    /// Human-readable name for this agent
    public var name: String
    /// User-provided session name (nil if not set)
    public var sessionName: String?
    /// The workspace this agent operates on
    public let workspace: Workspace
    /// Session ID for the ACP session (nil if not yet established)
    public var sessionId: SessionId?
    /// Current status of the agent
    public var status: AgentStatus
    /// Chat message history
    public var messages: [ChatMessage]
    /// Currently active tool calls (using SDK's ToolCallUpdate type)
    public var activeToolCalls: [ToolCallUpdate]
    /// File changes made by this agent
    public var fileChanges: [FileChange]
    /// Error message if status is .error
    public var errorMessage: String?
    /// Raw ACP debug log entries
    public var debugLog: [DebugLogEntry] = []
    /// All tool calls by ID, persisted after completion for chat history
    public var toolCallHistory: [String: ToolCallUpdate] = [:]
    
    /// Display name for the agent - returns sessionName if set, otherwise workspace name
    public var displayName: String {
        sessionName ?? workspace.name
    }
    
    /// Whether this agent has a custom session name vs auto-generated
    public var hasCustomSessionName: Bool {
        sessionName != nil
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        sessionName: String? = nil,
        workspace: Workspace,
        sessionId: SessionId? = nil,
        status: AgentStatus = .idle,
        messages: [ChatMessage] = [],
        activeToolCalls: [ToolCallUpdate] = [],
        fileChanges: [FileChange] = [],
        errorMessage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.sessionName = sessionName
        self.workspace = workspace
        self.sessionId = sessionId
        self.status = status
        self.messages = messages
        self.activeToolCalls = activeToolCalls
        self.fileChanges = fileChanges
        self.errorMessage = errorMessage
    }
}
#else
// Fallback for non-macOS platforms (Linux builds)
public final class Agent: Identifiable {
    public let id: UUID
    public var name: String
    public var sessionName: String?
    public let workspace: Workspace
    public var sessionId: SessionId?
    public var status: AgentStatus
    public var messages: [ChatMessage]
    public var activeToolCalls: [ToolCallUpdate]
    public var fileChanges: [FileChange]
    public var errorMessage: String?
    
    /// Display name for the agent - returns sessionName if set, otherwise workspace name
    public var displayName: String {
        sessionName ?? workspace.name
    }
    
    /// Whether this agent has a custom session name vs auto-generated
    public var hasCustomSessionName: Bool {
        sessionName != nil
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        sessionName: String? = nil,
        workspace: Workspace,
        sessionId: SessionId? = nil,
        status: AgentStatus = .idle,
        messages: [ChatMessage] = [],
        activeToolCalls: [ToolCallUpdate] = [],
        fileChanges: [FileChange] = [],
        errorMessage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.sessionName = sessionName
        self.workspace = workspace
        self.sessionId = sessionId
        self.status = status
        self.messages = messages
        self.activeToolCalls = activeToolCalls
        self.fileChanges = fileChanges
        self.errorMessage = errorMessage
    }
}
#endif
