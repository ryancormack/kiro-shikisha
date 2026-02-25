import Foundation

/// ACP method parameter and result types for JSON-RPC communication

// MARK: - Initialize Method

/// Parameters for the initialize method
public struct InitializeParams: Codable, Sendable {
    /// Protocol version (e.g., "1.0")
    public let protocolVersion: String
    /// Information about the client
    public let clientInfo: ClientInfo
    /// Client capabilities
    public let clientCapabilities: ClientCapabilities
    
    public init(protocolVersion: String, clientInfo: ClientInfo, clientCapabilities: ClientCapabilities) {
        self.protocolVersion = protocolVersion
        self.clientInfo = clientInfo
        self.clientCapabilities = clientCapabilities
    }
}

/// Result from the initialize method
public struct InitializeResult: Codable, Sendable {
    /// Protocol version supported by the agent
    public let protocolVersion: ProtocolVersion
    /// Information about the agent
    public let agentInfo: AgentInfo?
    /// Agent capabilities
    public let agentCapabilities: AgentCapabilities?
    
    public init(protocolVersion: ProtocolVersion, agentInfo: AgentInfo? = nil, agentCapabilities: AgentCapabilities? = nil) {
        self.protocolVersion = protocolVersion
        self.agentInfo = agentInfo
        self.agentCapabilities = agentCapabilities
    }
}

/// Protocol version that can be either a string or integer
public struct ProtocolVersion: Codable, Sendable {
    public let value: String
    
    public init(_ value: String) { self.value = value }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = String(intVal)
        } else {
            value = try container.decode(String.self)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - Session Methods

/// Parameters for session/new method
public struct SessionNewParams: Codable, Sendable {
    /// Current working directory for the session
    public let cwd: String
    /// MCP server configurations
    public let mcpServers: [JSONValue]
    
    public init(cwd: String, mcpServers: [JSONValue] = []) {
        self.cwd = cwd
        self.mcpServers = mcpServers
    }
}

/// Result from session/new method
public struct SessionNewResult: Codable, Sendable {
    /// Unique identifier for the created session
    public let sessionId: String
    
    public init(sessionId: String) {
        self.sessionId = sessionId
    }
}

/// Parameters for session/load method
public struct SessionLoadParams: Codable, Sendable {
    /// Session ID to load
    public let sessionId: String
    /// Current working directory
    public let cwd: String
    /// Optional MCP server configurations
    public let mcpServers: [String: JSONValue]?
    
    public init(sessionId: String, cwd: String, mcpServers: [String: JSONValue]? = nil) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.mcpServers = mcpServers
    }
}

/// Parameters for session/prompt method
public struct SessionPromptParams: Codable, Sendable {
    /// Session ID
    public let sessionId: String
    /// Prompt containing content blocks
    public let prompt: PromptContent
    
    public init(sessionId: String, content: [ContentBlock]) {
        self.sessionId = sessionId
        self.prompt = PromptContent(content: content)
    }
}

/// Prompt content wrapper
public struct PromptContent: Codable, Sendable {
    public let content: [ContentBlock]
}

/// Parameters for session/cancel method
public struct SessionCancelParams: Codable, Sendable {
    /// Session ID to cancel
    public let sessionId: String
    
    public init(sessionId: String) {
        self.sessionId = sessionId
    }
}

// MARK: - Content Types

/// Content block type for messages
public enum ContentBlockType: String, Codable, Sendable {
    case text
    case image
}

/// A block of content in a message (text or image)
public struct ContentBlock: Codable, Sendable {
    /// Type of content block
    public let type: ContentBlockType
    /// Text content (for text type)
    public let text: String?
    /// Base64-encoded data (for image type)
    public let data: String?
    /// Media type for images (e.g., "image/png")
    public let mediaType: String?
    
    public init(type: ContentBlockType, text: String? = nil, data: String? = nil, mediaType: String? = nil) {
        self.type = type
        self.text = text
        self.data = data
        self.mediaType = mediaType
    }
    
    /// Create a text content block
    public static func text(_ content: String) -> ContentBlock {
        ContentBlock(type: .text, text: content)
    }
    
    /// Create an image content block
    public static func image(data: String, mediaType: String) -> ContentBlock {
        ContentBlock(type: .image, data: data, mediaType: mediaType)
    }
}
