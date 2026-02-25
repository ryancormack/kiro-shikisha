import Foundation

/// ACP capability types for client-agent negotiation

// MARK: - Client Information

/// Information about the client application
public struct ClientInfo: Codable, Sendable {
    /// Client name
    public let name: String
    /// Client version
    public let version: String
    
    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

/// Information about the agent
public struct AgentInfo: Codable, Sendable {
    /// Agent name
    public let name: String
    /// Agent version
    public let version: String
    /// Agent title
    public let title: String?
    
    public init(name: String, version: String, title: String? = nil) {
        self.name = name
        self.version = version
        self.title = title
    }
}

// MARK: - Client Capabilities

/// Capabilities that the client provides to the agent
public struct ClientCapabilities: Codable, Sendable {
    /// File system capabilities
    public let fs: FileSystemCapabilities?
    /// Whether the client supports all terminal/* methods
    public let terminal: Bool?
    
    public init(fs: FileSystemCapabilities? = nil, terminal: Bool? = nil) {
        self.fs = fs
        self.terminal = terminal
    }
}

/// File system capabilities provided by the client
public struct FileSystemCapabilities: Codable, Sendable {
    /// Can read text files
    public let readTextFile: Bool
    /// Can write text files
    public let writeTextFile: Bool
    
    public init(readTextFile: Bool = false, writeTextFile: Bool = false) {
        self.readTextFile = readTextFile
        self.writeTextFile = writeTextFile
    }
}

/// Terminal capabilities provided by the client
public struct TerminalCapabilities: Codable, Sendable {
    /// Can execute commands
    public let execute: Bool
    
    public init(execute: Bool = false) {
        self.execute = execute
    }
}

// MARK: - Agent Capabilities

/// Capabilities that the agent provides
public struct AgentCapabilities: Codable, Sendable {
    /// Agent supports loading existing sessions
    public let loadSession: Bool?
    /// Prompt-related capabilities
    public let promptCapabilities: PromptCapabilities?
    
    public init(loadSession: Bool? = false, promptCapabilities: PromptCapabilities? = nil) {
        self.loadSession = loadSession
        self.promptCapabilities = promptCapabilities
    }
}

/// Capabilities related to prompts
public struct PromptCapabilities: Codable, Sendable {
    /// Agent supports image content in prompts
    public let image: Bool?
    /// Agent supports audio content
    public let audio: Bool?
    /// Agent supports embedded context
    public let embeddedContext: Bool?
    
    public init(image: Bool? = false, audio: Bool? = false, embeddedContext: Bool? = false) {
        self.image = image
        self.audio = audio
        self.embeddedContext = embeddedContext
    }
}
