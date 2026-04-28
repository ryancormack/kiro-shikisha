import Foundation

/// A portable instruction package discovered from SKILL.md files.
///
/// Skills live in either `.kiro/skills/<name>/SKILL.md` (workspace) or
/// `~/.kiro/skills/<name>/SKILL.md` (global). The optional `references/`
/// subfolder contains supplementary files that the skill's instructions
/// may direct the agent to read.
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
    /// Filenames discovered in `<skill>/references/` (relative to the references
    /// folder). Empty if the folder is missing or empty.
    public var references: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        sourcePath: String,
        isActive: Bool = false,
        references: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.sourcePath = sourcePath
        self.isActive = isActive
        self.references = references
    }
}
