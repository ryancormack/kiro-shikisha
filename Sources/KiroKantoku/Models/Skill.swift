import Foundation

/// A portable instruction package discovered from SKILL.md files
public struct Skill: Identifiable, Codable, Sendable, Hashable {
    /// Unique identifier for this skill
    public var id: UUID
    /// Human-readable name of the skill
    public var name: String
    /// Description of what the skill does
    public var description: String
    /// File path where the SKILL.md was found
    public var sourcePath: String
    /// Whether this skill is currently active in the session
    public var isActive: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        sourcePath: String,
        isActive: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.sourcePath = sourcePath
        self.isActive = isActive
    }
}
