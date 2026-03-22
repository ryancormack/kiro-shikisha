import Foundation
import ACPModel

/// Kiro-specific ACP extension notification types
/// These are vendor extensions used by kiro-cli that aren't part of the standard ACP spec

// MARK: - Kiro Extension Notifications

/// Parameters for _kiro.dev/commands/available notification
public struct KiroCommandsAvailableParams: Codable, Sendable {
    /// Session ID for which commands are available
    public let sessionId: String
    /// List of available commands
    public let commands: [KiroAvailableCommand]
    
    public init(sessionId: String, commands: [KiroAvailableCommand]) {
        self.sessionId = sessionId
        self.commands = commands
    }
}

/// An available command from Kiro extension
public struct KiroAvailableCommand: Codable, Sendable {
    /// Name of the command
    public let name: String
    /// Description of the command
    public let description: String
    /// Optional metadata about the command
    public let meta: JsonValue?
    
    public init(name: String, description: String, meta: JsonValue? = nil) {
        self.name = name
        self.description = description
        self.meta = meta
    }
}

/// Parameters for _kiro.dev/mcp/server_init_failure notification
public struct KiroMcpServerInitFailureParams: Codable, Sendable {
    /// Session ID where the failure occurred
    public let sessionId: String
    /// Name of the MCP server that failed to initialize
    public let serverName: String
    /// Error message describing the failure
    public let error: String
    
    public init(sessionId: String, serverName: String, error: String) {
        self.sessionId = sessionId
        self.serverName = serverName
        self.error = error
    }
}

// MARK: - Kiro Metadata

/// Parameters for _kiro.dev/metadata notification
public struct KiroMetadataParams: Codable, Sendable {
    /// Session ID
    public let sessionId: String
    /// Context usage percentage (0.0 to 100.0)
    public let contextUsagePercentage: Double
    
    public init(sessionId: String, contextUsagePercentage: Double) {
        self.sessionId = sessionId
        self.contextUsagePercentage = contextUsagePercentage
    }
}

// MARK: - Kiro Agent Switched

/// Parameters for _kiro.dev/agent/switched notification
public struct KiroAgentSwitchedParams: Codable, Sendable {
    /// Session ID
    public let sessionId: String
    /// Name of the new agent
    public let agentName: String
    /// Name of the previous agent
    public let previousAgentName: String
    /// Optional welcome message from the new agent
    public let welcomeMessage: String?
    
    public init(sessionId: String, agentName: String, previousAgentName: String, welcomeMessage: String? = nil) {
        self.sessionId = sessionId
        self.agentName = agentName
        self.previousAgentName = previousAgentName
        self.welcomeMessage = welcomeMessage
    }
}

// MARK: - Kiro Tool Call Chunk Update

/// Parameters for _kiro.dev/session/update with tool_call_chunk type
public struct KiroToolCallChunkUpdate: Codable, Sendable {
    /// Session update type (always "tool_call_chunk")
    public let sessionUpdate: String
    /// Tool call ID
    public let toolCallId: String
    /// Title of the tool call
    public let title: String
    /// Kind of tool call
    public let kind: String
    
    public init(sessionUpdate: String, toolCallId: String, title: String, kind: String) {
        self.sessionUpdate = sessionUpdate
        self.toolCallId = toolCallId
        self.title = title
        self.kind = kind
    }
}

// MARK: - Kiro Compaction Status

/// Parameters for _kiro.dev/compaction/status notification
public struct KiroCompactionStatusParams: Codable, Sendable {
    /// Status message about the compaction operation
    public let message: String
    
    public init(message: String) {
        self.message = message
    }
}

// MARK: - Kiro Clear Status

/// Parameters for _kiro.dev/clear/status notification
public struct KiroClearStatusParams: Codable, Sendable {
    /// Status message about the clear operation
    public let message: String
    
    public init(message: String) {
        self.message = message
    }
}

// MARK: - Kiro MCP OAuth Request

/// Parameters for _kiro.dev/mcp/oauth_request notification
public struct KiroMcpOAuthRequestParams: Codable, Sendable {
    /// OAuth URL to open
    public let url: String
    
    public init(url: String) {
        self.url = url
    }
}

// MARK: - Command Options

/// A single option returned from _kiro.dev/commands/options
public struct CommandOption: Codable, Sendable, Identifiable {
    public var id: String { value }
    public let value: String
    public let label: String
    public let description: String?
    public let group: String?
    
    public init(value: String, label: String, description: String? = nil, group: String? = nil) {
        self.value = value
        self.label = label
        self.description = description
        self.group = group
    }
}

/// Response from _kiro.dev/commands/options
public struct CommandOptionsResponse: Codable, Sendable {
    public let options: [CommandOption]
    public let hasMore: Bool
    
    public init(options: [CommandOption], hasMore: Bool = false) {
        self.options = options
        self.hasMore = hasMore
    }
}
