import XCTest
@testable import KiroKantoku

final class SkillTests: XCTestCase {

    func testSkillCreation() {
        let skill = Skill(name: "pr-review", description: "Review pull requests", sourcePath: "/path/to/SKILL.md")
        XCTAssertEqual(skill.name, "pr-review")
        XCTAssertEqual(skill.description, "Review pull requests")
        XCTAssertEqual(skill.sourcePath, "/path/to/SKILL.md")
        XCTAssertFalse(skill.isActive)
    }

    func testSkillCodableRoundTrip() throws {
        let skill = Skill(name: "cdk-deploy", description: "Deploy CDK stacks", sourcePath: "/skills/cdk/SKILL.md")
        let data = try JSONEncoder().encode(skill)
        let decoded = try JSONDecoder().decode(Skill.self, from: data)
        XCTAssertEqual(decoded.name, skill.name)
        XCTAssertEqual(decoded.description, skill.description)
        XCTAssertEqual(decoded.sourcePath, skill.sourcePath)
        XCTAssertEqual(decoded.isActive, skill.isActive)
    }

    func testParseSkillFrontmatter_valid() {
        let content = """
        ---
        name: pr-review
        description: Review pull requests for code quality, security issues, and test coverage.
        ---
        ## Review checklist
        Some instructions here.
        """
        let result = SkillDiscoveryService.parseSkillFrontmatter(content: content)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "pr-review")
        XCTAssertEqual(result?.description, "Review pull requests for code quality, security issues, and test coverage.")
    }

    func testParseSkillFrontmatter_noFrontmatter() {
        let content = "# Just a regular markdown file\nNo frontmatter here."
        let result = SkillDiscoveryService.parseSkillFrontmatter(content: content)
        XCTAssertNil(result)
    }

    func testParseSkillFrontmatter_missingDescription() {
        let content = """
        ---
        name: incomplete-skill
        ---
        # Content
        """
        let result = SkillDiscoveryService.parseSkillFrontmatter(content: content)
        XCTAssertNil(result)
    }

    func testParseSkillFrontmatter_missingName() {
        let content = """
        ---
        description: A skill without a name
        ---
        # Content
        """
        let result = SkillDiscoveryService.parseSkillFrontmatter(content: content)
        XCTAssertNil(result)
    }

    func testParseSkillFrontmatter_quotedValues() {
        let content = """
        ---
        name: "quoted-skill"
        description: "A skill with quoted values"
        ---
        # Content
        """
        let result = SkillDiscoveryService.parseSkillFrontmatter(content: content)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "quoted-skill")
        XCTAssertEqual(result?.description, "A skill with quoted values")
    }

    @MainActor
    func testAgentAvailableSkillsDefault() {
        let workspace = Workspace(name: "Test", path: URL(fileURLWithPath: "/tmp/test"))
        let agent = Agent(name: "Test Agent", workspace: workspace)
        XCTAssertTrue(agent.availableSkills.isEmpty)
    }

    func testSkillDiscoveryWithFilesystem() throws {
        // Create a temp directory with a skill
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let skillDir = tempDir.appendingPathComponent(".kiro/skills/test-skill")
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let skillContent = """
        ---
        name: test-skill
        description: A test skill for unit testing
        ---
        # Test Skill
        Instructions here.
        """
        try skillContent.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let service = SkillDiscoveryService()
        let skills = service.discoverSkills(workspacePath: tempDir)
        XCTAssertEqual(skills.count, 1)
        XCTAssertEqual(skills.first?.name, "test-skill")
        XCTAssertEqual(skills.first?.description, "A test skill for unit testing")
    }

    func testSkillHashable() {
        let skill1 = Skill(name: "skill-a", description: "Desc A", sourcePath: "/a/SKILL.md")
        let skill2 = Skill(name: "skill-a", description: "Desc A", sourcePath: "/a/SKILL.md", isActive: true)
        // Different isActive means different hash
        XCTAssertNotEqual(skill1, skill2)
        // Same values should be equal
        let skill3 = Skill(id: skill1.id, name: "skill-a", description: "Desc A", sourcePath: "/a/SKILL.md")
        XCTAssertEqual(skill1, skill3)
    }

    // MARK: - References folder discovery

    func testSkillDefaultReferencesIsEmpty() {
        let skill = Skill(name: "pr-review", description: "desc", sourcePath: "/path/SKILL.md")
        XCTAssertTrue(skill.references.isEmpty)
    }

    func testSkillDiscoveryPopulatesReferencesFolder() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let skillDir = tempDir.appendingPathComponent(".kiro/skills/cdk-deploy")
        let referencesDir = skillDir.appendingPathComponent("references")
        try FileManager.default.createDirectory(at: referencesDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let skillContent = """
        ---
        name: cdk-deploy
        description: Deploy AWS CDK stacks
        ---
        See references/stack-patterns.md for details.
        """
        try skillContent.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try "# Stack patterns".write(to: referencesDir.appendingPathComponent("stack-patterns.md"), atomically: true, encoding: .utf8)
        try "# Troubleshooting".write(to: referencesDir.appendingPathComponent("troubleshooting.md"), atomically: true, encoding: .utf8)

        let service = SkillDiscoveryService()
        let skill = service.discoverSkills(workspacePath: tempDir).first(where: { $0.name == "cdk-deploy" })

        XCTAssertNotNil(skill, "expected to discover the cdk-deploy skill")
        XCTAssertEqual(skill?.references.sorted(), ["stack-patterns.md", "troubleshooting.md"])
    }

    func testSkillDiscoveryHasEmptyReferencesWhenFolderMissing() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let skillDir = tempDir.appendingPathComponent(".kiro/skills/simple")
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let skillContent = """
        ---
        name: simple
        description: No reference files at all
        ---
        Just instructions.
        """
        try skillContent.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let service = SkillDiscoveryService()
        let skill = service.discoverSkills(workspacePath: tempDir).first(where: { $0.name == "simple" })

        XCTAssertNotNil(skill)
        XCTAssertEqual(skill?.references, [])
    }

    func testSkillDiscoveryReferencesSkipsHiddenFilesAndSubdirs() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let skillDir = tempDir.appendingPathComponent(".kiro/skills/deep")
        let referencesDir = skillDir.appendingPathComponent("references")
        let nestedDir = referencesDir.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try """
        ---
        name: deep
        description: Skill with nested references folder
        ---
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try "".write(to: referencesDir.appendingPathComponent("guide.md"), atomically: true, encoding: .utf8)
        try "".write(to: referencesDir.appendingPathComponent(".DS_Store"), atomically: true, encoding: .utf8)
        try "".write(to: nestedDir.appendingPathComponent("ignored.md"), atomically: true, encoding: .utf8)

        let service = SkillDiscoveryService()
        let skill = service.discoverSkills(workspacePath: tempDir).first(where: { $0.name == "deep" })

        // Only the immediate regular file "guide.md" should be picked up.
        // Subdirectories and hidden files are excluded.
        XCTAssertEqual(skill?.references, ["guide.md"])
    }
}

