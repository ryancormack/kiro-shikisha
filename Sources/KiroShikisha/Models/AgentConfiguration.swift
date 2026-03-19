import Foundation

/// A named agent configuration profile that determines which agent flag is passed to kiro-cli.
public struct AgentConfiguration: Identifiable, Codable, Sendable, Hashable {
    /// Unique identifier for this configuration
    public let id: UUID
    /// Human-readable name for this configuration
    public var name: String
    /// Value passed via --agent flag to kiro-cli
    public var agentFlag: String
    /// Tags for organizing configurations
    public var tags: [String]
    /// Whether this is the default configuration
    public var isDefault: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        agentFlag: String,
        tags: [String] = [],
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.agentFlag = agentFlag
        self.tags = tags
        self.isDefault = isDefault
    }
}
