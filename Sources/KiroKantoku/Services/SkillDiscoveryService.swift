import Foundation

/// Service that discovers skills by scanning directories for SKILL.md files
public struct SkillDiscoveryService {

    public init() {}

    /// Discover skills from workspace-local and global skill directories.
    /// Workspace skills override global skills with the same name.
    /// - Parameter workspacePath: The root URL of the workspace
    /// - Returns: Array of discovered skills (workspace skills take precedence over global)
    public func discoverSkills(workspacePath: URL) -> [Skill] {
        let fm = FileManager.default

        // Scan workspace skills
        let workspaceSkillsDir = workspacePath.appendingPathComponent(".kiro/skills")
        let workspaceSkills = scanSkillsDirectory(workspaceSkillsDir, fileManager: fm)

        // Scan global skills (~/.kiro/skills/)
        let homeDir = fm.homeDirectoryForCurrentUser
        let globalSkillsDir = homeDir.appendingPathComponent(".kiro/skills")
        let globalSkills = scanSkillsDirectory(globalSkillsDir, fileManager: fm)

        // Dedup by name, workspace wins
        var skillsByName: [String: Skill] = [:]
        for skill in globalSkills {
            skillsByName[skill.name] = skill
        }
        for skill in workspaceSkills {
            skillsByName[skill.name] = skill
        }

        return Array(skillsByName.values).sorted { $0.name < $1.name }
    }

    /// Scan a skills directory for subdirectories containing SKILL.md files
    private func scanSkillsDirectory(_ directory: URL, fileManager: FileManager) -> [Skill] {
        var skills: [Skill] = []
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return skills
        }

        for item in contents {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            let skillFile = item.appendingPathComponent("SKILL.md")
            guard fileManager.fileExists(atPath: skillFile.path),
                  let content = try? String(contentsOf: skillFile, encoding: .utf8),
                  let parsed = Self.parseSkillFrontmatter(content: content) else {
                continue
            }
            let references = Self.scanReferences(skillFolder: item, fileManager: fileManager)
            let skill = Skill(
                name: parsed.name,
                description: parsed.description,
                sourcePath: skillFile.path,
                references: references
            )
            skills.append(skill)
        }
        return skills
    }

    /// Enumerate files inside the skill's `references/` folder, if present.
    /// Only immediate children are listed — the reference folder structure is shallow
    /// per the Agent Skills spec. Hidden files and subdirectories are skipped.
    private static func scanReferences(skillFolder: URL, fileManager: FileManager) -> [String] {
        let referencesDir = skillFolder.appendingPathComponent("references")
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: referencesDir.path, isDirectory: &isDir), isDir.boolValue else {
            return []
        }
        guard let entries = try? fileManager.contentsOfDirectory(
            at: referencesDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return entries
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false }
            .map { $0.lastPathComponent }
            .sorted()
    }

    /// Parse YAML frontmatter from a SKILL.md file to extract name and description.
    /// - Parameter content: The full text content of a SKILL.md file
    /// - Returns: A tuple of (name, description) if both fields are found, nil otherwise
    public static func parseSkillFrontmatter(content: String) -> (name: String, description: String)? {
        let lines = content.components(separatedBy: .newlines)

        // Find opening ---
        guard let firstDelimiterIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return nil
        }

        // Find closing ---
        let searchStart = lines.index(after: firstDelimiterIndex)
        guard searchStart < lines.endIndex else { return nil }
        let remaining = lines[searchStart...]
        guard let secondDelimiterIndex = remaining.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return nil
        }

        let frontmatterLines = lines[(firstDelimiterIndex + 1)..<secondDelimiterIndex]

        var name: String?
        var description: String?

        for line in frontmatterLines {
            if let value = extractYAMLValue(line: line, key: "name") {
                name = value
            } else if let value = extractYAMLValue(line: line, key: "description") {
                description = value
            }
        }

        guard let name = name, !name.isEmpty,
              let description = description, !description.isEmpty else {
            return nil
        }

        return (name: name, description: description)
    }

    /// Extract a value for a given key from a YAML-like line (e.g. "name: value" or "name: \"value\"")
    private static func extractYAMLValue(line: String, key: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let prefix = "\(key):"
        guard trimmed.hasPrefix(prefix) else { return nil }
        var value = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        // Strip surrounding quotes if present
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
           (value.hasPrefix("'") && value.hasSuffix("'")) {
            value = String(value.dropFirst().dropLast())
        }
        return value.isEmpty ? nil : value
    }
}
