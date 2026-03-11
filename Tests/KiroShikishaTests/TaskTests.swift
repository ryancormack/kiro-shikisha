import XCTest
@testable import KiroShikisha

final class TaskTests: XCTestCase {

    // MARK: - AgentTask Tests

    func testAgentTaskCreation() async throws {
        await MainActor.run {
            let path = URL(fileURLWithPath: "/Users/test/projects/myproject")
            let task = AgentTask(
                name: "Implement feature X",
                workspacePath: path
            )

            XCTAssertEqual(task.name, "Implement feature X")
            XCTAssertEqual(task.status, .pending)
            XCTAssertEqual(task.workspacePath, path)
            XCTAssertNil(task.gitBranch)
            XCTAssertNil(task.sourceWorkspaceId)
            XCTAssertNil(task.agentId)
            XCTAssertNil(task.sessionId)
            XCTAssertTrue(task.fileChanges.isEmpty)
            XCTAssertNil(task.startedAt)
            XCTAssertNil(task.completedAt)
            XCTAssertNil(task.lastActivityAt)
            XCTAssertNil(task.attentionReason)
            XCTAssertTrue(task.messages.isEmpty)
            XCTAssertFalse(task.useWorktree)
            XCTAssertNil(task.worktreeBranchName)
        }
    }

    func testAgentTaskCreationWithAllProperties() async throws {
        await MainActor.run {
            let path = URL(fileURLWithPath: "/Users/test/projects/repo")
            let sourceId = UUID()
            let agentId = UUID()
            let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)
            let message = ChatMessage(role: .system, content: "Agent connected.")

            let task = AgentTask(
                name: "Fix bug Y",
                status: .working,
                workspacePath: path,
                gitBranch: "fix/bug-y",
                sourceWorkspaceId: sourceId,
                agentId: agentId,
                sessionId: "session-123",
                fileChanges: [],
                createdAt: fixedDate,
                startedAt: fixedDate,
                completedAt: nil,
                lastActivityAt: fixedDate,
                attentionReason: nil,
                messages: [message]
            )

            XCTAssertEqual(task.name, "Fix bug Y")
            XCTAssertEqual(task.status, .working)
            XCTAssertEqual(task.workspacePath, path)
            XCTAssertEqual(task.gitBranch, "fix/bug-y")
            XCTAssertEqual(task.sourceWorkspaceId, sourceId)
            XCTAssertEqual(task.agentId, agentId)
            XCTAssertEqual(task.sessionId, "session-123")
            XCTAssertEqual(task.createdAt, fixedDate)
            XCTAssertEqual(task.startedAt, fixedDate)
            XCTAssertNil(task.completedAt)
            XCTAssertEqual(task.lastActivityAt, fixedDate)
            XCTAssertEqual(task.messages.count, 1)
            XCTAssertEqual(task.messages[0].content, "Agent connected.")
        }
    }

    // MARK: - TaskStatus Tests

    func testTaskStatusIsActive() throws {
        // Active statuses
        XCTAssertTrue(TaskStatus.starting.isActive)
        XCTAssertTrue(TaskStatus.working.isActive)
        XCTAssertTrue(TaskStatus.needsAttention.isActive)

        // Non-active statuses
        XCTAssertFalse(TaskStatus.pending.isActive)
        XCTAssertFalse(TaskStatus.paused.isActive)
        XCTAssertFalse(TaskStatus.completed.isActive)
        XCTAssertFalse(TaskStatus.failed.isActive)
        XCTAssertFalse(TaskStatus.cancelled.isActive)
    }

    func testTaskStatusIsTerminal() throws {
        // Terminal statuses
        XCTAssertTrue(TaskStatus.completed.isTerminal)
        XCTAssertTrue(TaskStatus.failed.isTerminal)
        XCTAssertTrue(TaskStatus.cancelled.isTerminal)

        // Non-terminal statuses
        XCTAssertFalse(TaskStatus.pending.isTerminal)
        XCTAssertFalse(TaskStatus.starting.isTerminal)
        XCTAssertFalse(TaskStatus.working.isTerminal)
        XCTAssertFalse(TaskStatus.needsAttention.isTerminal)
        XCTAssertFalse(TaskStatus.paused.isTerminal)
    }

    func testTaskStatusNeedsAttention() throws {
        XCTAssertTrue(TaskStatus.needsAttention.needsAttention)

        XCTAssertFalse(TaskStatus.pending.needsAttention)
        XCTAssertFalse(TaskStatus.starting.needsAttention)
        XCTAssertFalse(TaskStatus.working.needsAttention)
        XCTAssertFalse(TaskStatus.paused.needsAttention)
        XCTAssertFalse(TaskStatus.completed.needsAttention)
        XCTAssertFalse(TaskStatus.failed.needsAttention)
        XCTAssertFalse(TaskStatus.cancelled.needsAttention)
    }

    func testTaskStatusIconName() throws {
        let allStatuses: [TaskStatus] = [
            .pending, .starting, .working, .needsAttention,
            .paused, .completed, .failed, .cancelled
        ]

        for status in allStatuses {
            XCTAssertFalse(status.iconName.isEmpty, "iconName should not be empty for \(status)")
        }

        // Verify specific icon names
        XCTAssertEqual(TaskStatus.pending.iconName, "circle.dashed")
        XCTAssertEqual(TaskStatus.starting.iconName, "arrow.trianglehead.clockwise")
        XCTAssertEqual(TaskStatus.working.iconName, "gearshape.fill")
        XCTAssertEqual(TaskStatus.needsAttention.iconName, "exclamationmark.triangle.fill")
        XCTAssertEqual(TaskStatus.paused.iconName, "pause.circle.fill")
        XCTAssertEqual(TaskStatus.completed.iconName, "checkmark.circle.fill")
        XCTAssertEqual(TaskStatus.failed.iconName, "xmark.circle.fill")
        XCTAssertEqual(TaskStatus.cancelled.iconName, "slash.circle.fill")
    }

    func testTaskStatusRawValues() throws {
        XCTAssertEqual(TaskStatus.pending.rawValue, "pending")
        XCTAssertEqual(TaskStatus.starting.rawValue, "starting")
        XCTAssertEqual(TaskStatus.working.rawValue, "working")
        XCTAssertEqual(TaskStatus.needsAttention.rawValue, "needsAttention")
        XCTAssertEqual(TaskStatus.paused.rawValue, "paused")
        XCTAssertEqual(TaskStatus.completed.rawValue, "completed")
        XCTAssertEqual(TaskStatus.failed.rawValue, "failed")
        XCTAssertEqual(TaskStatus.cancelled.rawValue, "cancelled")
    }

    // MARK: - TaskCreationRequest Tests

    func testTaskCreationRequest() throws {
        let path = URL(fileURLWithPath: "/Users/test/projects/repo")

        let request = TaskCreationRequest(
            name: "Add new feature",
            workspacePath: path,
            gitBranch: "feature/new",
            useWorktree: true
        )

        XCTAssertEqual(request.name, "Add new feature")
        XCTAssertEqual(request.workspacePath, path)
        XCTAssertEqual(request.gitBranch, "feature/new")
        XCTAssertTrue(request.useWorktree)
        XCTAssertNil(request.worktreeBranchName)
    }

    func testTaskCreationRequestDefaults() throws {
        let path = URL(fileURLWithPath: "/Users/test/projects/repo")

        let request = TaskCreationRequest(
            name: "Simple task",
            workspacePath: path
        )

        XCTAssertEqual(request.name, "Simple task")
        XCTAssertEqual(request.workspacePath, path)
        XCTAssertNil(request.gitBranch)
        XCTAssertFalse(request.useWorktree)
        XCTAssertNil(request.worktreeBranchName)
    }

    func testTaskCreationRequestWithWorktree() throws {
        let path = URL(fileURLWithPath: "/Users/test/projects/repo")

        let request = TaskCreationRequest(
            name: "Feature task",
            workspacePath: path,
            gitBranch: "feature/new-thing",
            useWorktree: true,
            worktreeBranchName: "feature/new-thing"
        )

        XCTAssertEqual(request.name, "Feature task")
        XCTAssertEqual(request.workspacePath, path)
        XCTAssertEqual(request.gitBranch, "feature/new-thing")
        XCTAssertTrue(request.useWorktree)
        XCTAssertEqual(request.worktreeBranchName, "feature/new-thing")
    }

    func testAgentTaskWithWorktreeProperties() async throws {
        await MainActor.run {
            let path = URL(fileURLWithPath: "/Users/test/projects/repo")
            let task = AgentTask(
                name: "Worktree Task",
                workspacePath: path,
                gitBranch: "feature/wt",
                useWorktree: true,
                worktreeBranchName: "feature/wt"
            )
            XCTAssertTrue(task.useWorktree)
            XCTAssertEqual(task.worktreeBranchName, "feature/wt")
            XCTAssertEqual(task.gitBranch, "feature/wt")
        }
    }
}
