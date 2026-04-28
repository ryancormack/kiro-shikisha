#if os(macOS)
import XCTest
import ACPModel
@testable import KiroKantoku

/// Tests for `mergeSlashCommands` covering the allow-list-replacement behavior,
/// skill merging, and ordering guarantees.
final class SlashCommandMergeTests: XCTestCase {

    // MARK: - Pass-through behavior (the docs-alignment fix)

    func testBuiltInKiroCommandsPassThrough() {
        // Previously these were all dropped by a 6-item allow-list; they must
        // now appear in the merged list because kiro-cli advertises them.
        let kiroCommands = [
            KiroAvailableCommand(name: "/agent", description: "Manage agents"),
            KiroAvailableCommand(name: "/chat", description: "Session management"),
            KiroAvailableCommand(name: "/model", description: "Switch model"),
            KiroAvailableCommand(name: "/clear", description: "Clear chat"),
            KiroAvailableCommand(name: "/mcp", description: "Show MCP servers"),
            KiroAvailableCommand(name: "/checkpoint", description: "Manage checkpoints"),
            KiroAvailableCommand(name: "/plan", description: "Plan agent"),
            KiroAvailableCommand(name: "/knowledge", description: "Knowledge base"),
            KiroAvailableCommand(name: "/usage", description: "Billing info"),
        ]
        let merged = mergeSlashCommands(acpCommands: [], kiroCommands: kiroCommands)
        let names = Set(merged.map { $0.name })

        let expected: Set<String> = [
            "agent", "chat", "model", "clear", "mcp",
            "checkpoint", "plan", "knowledge", "usage",
        ]
        XCTAssertEqual(names, expected,
                       "every advertised command should be visible; the old allow-list is gone")
    }

    func testGuiIncompatibleCommandsAreFiltered() {
        // These commands either open $EDITOR, $PAGER, or otherwise don't make
        // sense inside a Mac app, so they must be dropped from the picker.
        let kiroCommands = [
            KiroAvailableCommand(name: "/editor", description: "Open $EDITOR"),
            KiroAvailableCommand(name: "/reply", description: "Reply in $EDITOR"),
            KiroAvailableCommand(name: "/transcript", description: "Open in $PAGER"),
            KiroAvailableCommand(name: "/logdump", description: "Dump logs"),
            KiroAvailableCommand(name: "/theme", description: "Terminal theme"),
            KiroAvailableCommand(name: "/experiment", description: "Toggle features"),
            KiroAvailableCommand(name: "/paste", description: "Paste image"),
            KiroAvailableCommand(name: "/todos", description: "Manage todos"),
            KiroAvailableCommand(name: "/issue", description: "File an issue"),
            KiroAvailableCommand(name: "/tangent", description: "Tangent mode"),
            KiroAvailableCommand(name: "/quit", description: "Quit"),
            KiroAvailableCommand(name: "/exit", description: "Exit"),
            // Not GUI-incompatible; should survive.
            KiroAvailableCommand(name: "/compact", description: "Compact history"),
        ]
        let merged = mergeSlashCommands(acpCommands: [], kiroCommands: kiroCommands)
        let names = Set(merged.map { $0.name })

        XCTAssertTrue(names.contains("compact"))
        for blocked in ["editor", "reply", "transcript", "logdump", "theme",
                        "experiment", "paste", "todos", "issue", "tangent",
                        "quit", "exit"] {
            XCTAssertFalse(names.contains(blocked), "\(blocked) should be filtered")
        }
    }

    func testAcpCommandsFillGapsLeftByKiro() {
        // When Kiro doesn't advertise a command but standard ACP does, the ACP
        // version must still reach the picker.
        let acpCommands = [
            AvailableCommand(name: "help", description: "Help"),
            AvailableCommand(name: "context", description: "Context"),
        ]
        let merged = mergeSlashCommands(acpCommands: acpCommands, kiroCommands: [])
        let names = merged.map { $0.name }
        XCTAssertEqual(Set(names), ["help", "context"])
    }

    // MARK: - Deduplication

    func testKiroCommandWinsOverAcpCommandWithSameName() {
        // Kiro's richer metadata should be preserved when both sources advertise
        // the same command.
        let acpCommands = [
            AvailableCommand(name: "/model", description: "ACP description")
        ]
        let kiroCommands = [
            KiroAvailableCommand(
                name: "/model",
                description: "Kiro description",
                meta: .object(["inputType": .string("selection")])
            )
        ]
        let merged = mergeSlashCommands(acpCommands: acpCommands, kiroCommands: kiroCommands)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.description, "Kiro description")
        XCTAssertEqual(merged.first?.inputType, .selection)
    }

    // MARK: - Skill integration

    func testSkillsBecomeSlashCommandsAtEndOfList() {
        let kiroCommands = [
            KiroAvailableCommand(name: "/agent", description: "Agents"),
            KiroAvailableCommand(name: "/model", description: "Models"),
        ]
        let skills = [
            Skill(name: "pr-review", description: "Review PRs", sourcePath: "/a/SKILL.md"),
            Skill(name: "cdk-deploy", description: "Deploy CDK", sourcePath: "/b/SKILL.md"),
        ]
        let merged = mergeSlashCommands(acpCommands: [], kiroCommands: kiroCommands, skills: skills)

        let names = merged.map { $0.name }
        XCTAssertEqual(names, ["agent", "model", "cdk-deploy", "pr-review"],
                       "built-ins come first alphabetically, then skills alphabetically")

        // Only the skill entries should carry the Skill flag.
        for cmd in merged {
            if cmd.name == "cdk-deploy" || cmd.name == "pr-review" {
                XCTAssertTrue(cmd.isSkill, "\(cmd.name) should be flagged as a skill")
            } else {
                XCTAssertFalse(cmd.isSkill, "\(cmd.name) is a built-in, not a skill")
            }
        }
    }

    func testSkillDoesNotCollideWithServerAdvertisedCommand() {
        // If kiro-cli also advertises a skill as a real slash command, prefer
        // the server entry so we keep its description and metadata.
        let kiroCommands = [
            KiroAvailableCommand(name: "/pr-review", description: "Server-side PR review"),
        ]
        let skills = [
            Skill(name: "pr-review", description: "Local skill description", sourcePath: "/a/SKILL.md"),
        ]
        let merged = mergeSlashCommands(acpCommands: [], kiroCommands: kiroCommands, skills: skills)

        let prReview = merged.first(where: { $0.name == "pr-review" })
        XCTAssertNotNil(prReview)
        XCTAssertEqual(prReview?.description, "Server-side PR review",
                       "kiro-cli's advertised command should win over the local skill")
        XCTAssertFalse(prReview?.isSkill ?? true,
                       "since kiro-cli advertised it, this entry is treated as a real command, not a skill marker")
        XCTAssertEqual(merged.count, 1, "no duplicates")
    }

    func testEmptyInputReturnsEmptyList() {
        let merged = mergeSlashCommands(acpCommands: [], kiroCommands: [], skills: [])
        XCTAssertTrue(merged.isEmpty)
    }

    func testOnlySkillsAreStillUsable() {
        // A workspace with no server-advertised commands but one skill should
        // still surface that skill as a slash command.
        let skills = [
            Skill(name: "alb-log-diagnosis", description: "Diagnose ALB logs", sourcePath: "/a/SKILL.md"),
        ]
        let merged = mergeSlashCommands(acpCommands: [], kiroCommands: [], skills: skills)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.name, "alb-log-diagnosis")
        XCTAssertTrue(merged.first?.isSkill ?? false)
    }
}
#endif
