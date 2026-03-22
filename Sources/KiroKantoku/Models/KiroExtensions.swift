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
