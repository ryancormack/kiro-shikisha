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
        XCTAssertTrue(request.startImmediately)
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
        XCTAssertTrue(request.startImmediately)
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
        XCTAssertTrue(request.startImmediately)
    }

    func testTaskCreationRequestStartImmediatelyFalse() throws {
        let path = URL(fileURLWithPath: "/Users/test/projects/repo")

        let request = TaskCreationRequest(
            name: "Deferred task",
            workspacePath: path,
            startImmediately: false
        )

        XCTAssertEqual(request.name, "Deferred task")
        XCTAssertEqual(request.workspacePath, path)
        XCTAssertFalse(request.startImmediately)
        XCTAssertNil(request.gitBranch)
        XCTAssertFalse(request.useWorktree)
        XCTAssertNil(request.worktreeBranchName)
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

    // MARK: - Task Persistence Tests

    func testTaskPersistenceEntryRoundTrip() throws {
        let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)
        let completedDate = Date(timeIntervalSinceReferenceDate: 700003600)
        let activityDate = Date(timeIntervalSinceReferenceDate: 700003500)
        let entryId = UUID()

        let entry = AppStateManager.TaskPersistenceEntry(
            id: entryId,
            name: "Test persistence task",
            statusRawValue: "completed",
            workspacePath: "/Users/test/projects/repo",
            gitBranch: "feature/persist",
            createdAt: fixedDate,
            completedAt: completedDate,
            lastActivityAt: activityDate
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AppStateManager.TaskPersistenceEntry.self, from: data)

        XCTAssertEqual(decoded.id, entryId)
        XCTAssertEqual(decoded.name, "Test persistence task")
        XCTAssertEqual(decoded.statusRawValue, "completed")
        XCTAssertEqual(decoded.workspacePath, "/Users/test/projects/repo")
        XCTAssertEqual(decoded.gitBranch, "feature/persist")
        XCTAssertEqual(decoded.createdAt, fixedDate)
        XCTAssertEqual(decoded.completedAt, completedDate)
        XCTAssertEqual(decoded.lastActivityAt, activityDate)
    }

    func testTaskManagerRestoreTasks() async throws {
        await MainActor.run {
            let taskManager = TaskManager()
            let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)
            let completedDate = Date(timeIntervalSinceReferenceDate: 700003600)

            let workingEntry = AppStateManager.TaskPersistenceEntry(
                id: UUID(),
                name: "Working task",
                statusRawValue: "working",
                workspacePath: "/Users/test/projects/repo1",
                gitBranch: "feature/a",
                createdAt: fixedDate
            )

            let completedEntry = AppStateManager.TaskPersistenceEntry(
                id: UUID(),
                name: "Completed task",
                statusRawValue: "completed",
                workspacePath: "/Users/test/projects/repo2",
                createdAt: fixedDate,
                completedAt: completedDate
            )

            let pendingEntry = AppStateManager.TaskPersistenceEntry(
                id: UUID(),
                name: "Pending task",
                statusRawValue: "pending",
                workspacePath: "/Users/test/projects/repo3",
                createdAt: fixedDate
            )

            taskManager.restoreTasks(from: [workingEntry, completedEntry, pendingEntry])

            XCTAssertEqual(taskManager.tasks.count, 3)

            // Working task should be restored as paused
            let restoredWorking = taskManager.tasks[workingEntry.id]
            XCTAssertNotNil(restoredWorking)
            XCTAssertEqual(restoredWorking?.status, .paused)
            XCTAssertEqual(restoredWorking?.name, "Working task")
            XCTAssertEqual(restoredWorking?.gitBranch, "feature/a")

            // Completed task should remain completed
            let restoredCompleted = taskManager.tasks[completedEntry.id]
            XCTAssertNotNil(restoredCompleted)
            XCTAssertEqual(restoredCompleted?.status, .completed)
            XCTAssertEqual(restoredCompleted?.completedAt, completedDate)

            // Pending task should remain pending
            let restoredPending = taskManager.tasks[pendingEntry.id]
            XCTAssertNotNil(restoredPending)
            XCTAssertEqual(restoredPending?.status, .pending)
        }
    }

    func testCompleteTaskSetsStatusAndDate() async throws {
        await MainActor.run {
            let taskManager = TaskManager()
            let path = URL(fileURLWithPath: "/Users/test/projects/repo")
            let request = TaskCreationRequest(name: "Task to complete", workspacePath: path)
            let task = taskManager.createTask(from: request)

            XCTAssertEqual(task.status, .pending)
            XCTAssertNil(task.completedAt)

            taskManager.completeTask(id: task.id)

            XCTAssertEqual(task.status, .completed)
            XCTAssertNotNil(task.completedAt)
            XCTAssertNotNil(task.lastActivityAt)
        }
    }

    func testTaskManagerRestorePreservesTerminalStatus() async throws {
        await MainActor.run {
            let taskManager = TaskManager()
            let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)
            let completedDate = Date(timeIntervalSinceReferenceDate: 700003600)

            let completedEntry = AppStateManager.TaskPersistenceEntry(
                id: UUID(),
                name: "Completed task",
                statusRawValue: "completed",
                workspacePath: "/Users/test/projects/repo1",
                createdAt: fixedDate,
                completedAt: completedDate
            )

            let cancelledEntry = AppStateManager.TaskPersistenceEntry(
                id: UUID(),
                name: "Cancelled task",
                statusRawValue: "cancelled",
                workspacePath: "/Users/test/projects/repo2",
                createdAt: fixedDate
            )

            taskManager.restoreTasks(from: [completedEntry, cancelledEntry])

            XCTAssertEqual(taskManager.tasks.count, 2)

            let restoredCompleted = taskManager.tasks[completedEntry.id]
            XCTAssertEqual(restoredCompleted?.status, .completed)

            let restoredCancelled = taskManager.tasks[cancelledEntry.id]
            XCTAssertEqual(restoredCancelled?.status, .cancelled)
        }
    }

    // MARK: - Reactive Persistence Tests

    func testTaskPersistenceEntryFromAgentTask() async throws {
        await MainActor.run {
            let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)
            let completedDate = Date(timeIntervalSinceReferenceDate: 700003600)
            let activityDate = Date(timeIntervalSinceReferenceDate: 700003500)
            let path = URL(fileURLWithPath: "/Users/test/projects/myproject")

            let task = AgentTask(
                name: "Test Task",
                status: .completed,
                workspacePath: path,
                gitBranch: "feature/test",
                createdAt: fixedDate,
                completedAt: completedDate,
                lastActivityAt: activityDate
            )

            let entry = AppStateManager.TaskPersistenceEntry(
                id: task.id,
                name: task.name,
                statusRawValue: task.status.rawValue,
                workspacePath: task.workspacePath.path,
                gitBranch: task.gitBranch,
                createdAt: task.createdAt,
                completedAt: task.completedAt,
                lastActivityAt: task.lastActivityAt
            )

            XCTAssertEqual(entry.id, task.id)
            XCTAssertEqual(entry.name, "Test Task")
            XCTAssertEqual(entry.statusRawValue, "completed")
            XCTAssertEqual(entry.workspacePath, path.path)
            XCTAssertEqual(entry.gitBranch, "feature/test")
            XCTAssertEqual(entry.createdAt, fixedDate)
            XCTAssertEqual(entry.completedAt, completedDate)
            XCTAssertEqual(entry.lastActivityAt, activityDate)
        }
    }

    func testTaskManagerPersistenceAfterCreate() async throws {
        await MainActor.run {
            let taskManager = TaskManager()
            let appStateManager = AppStateManager()
            taskManager.appStateManager = appStateManager

            let path = URL(fileURLWithPath: "/Users/test/projects/repo")
            let request = TaskCreationRequest(name: "Persisted task", workspacePath: path)
            let task = taskManager.createTask(from: request)

            // On Linux, persistTasks is a no-op on AppStateManager,
            // but we can verify the task was created correctly
            XCTAssertEqual(taskManager.tasks.count, 1)
            XCTAssertEqual(taskManager.tasks[task.id]?.name, "Persisted task")
            XCTAssertEqual(taskManager.tasks[task.id]?.status, .pending)
        }
    }

    func testTaskPersistenceEntryNilOptionals() throws {
        let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)

        let entry = AppStateManager.TaskPersistenceEntry(
            id: UUID(),
            name: "Minimal task",
            statusRawValue: "pending",
            workspacePath: "/Users/test/projects/repo",
            gitBranch: nil,
            createdAt: fixedDate,
            completedAt: nil,
            lastActivityAt: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AppStateManager.TaskPersistenceEntry.self, from: data)

        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.name, "Minimal task")
        XCTAssertEqual(decoded.statusRawValue, "pending")
        XCTAssertEqual(decoded.workspacePath, "/Users/test/projects/repo")
        XCTAssertNil(decoded.gitBranch)
        XCTAssertEqual(decoded.createdAt, fixedDate)
        XCTAssertNil(decoded.completedAt)
        XCTAssertNil(decoded.lastActivityAt)
    }

    func testTaskManagerRestoreAndMutate() async throws {
        await MainActor.run {
            let taskManager = TaskManager()
            let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)

            let workingEntry = AppStateManager.TaskPersistenceEntry(
                id: UUID(),
                name: "Active task",
                statusRawValue: "working",
                workspacePath: "/Users/test/projects/repo1",
                gitBranch: "feature/a",
                createdAt: fixedDate
            )

            let pendingEntry = AppStateManager.TaskPersistenceEntry(
                id: UUID(),
                name: "Pending task",
                statusRawValue: "pending",
                workspacePath: "/Users/test/projects/repo2",
                createdAt: fixedDate
            )

            taskManager.restoreTasks(from: [workingEntry, pendingEntry])

            // Working task should be restored as paused
            XCTAssertEqual(taskManager.tasks[workingEntry.id]?.status, .paused)
            XCTAssertEqual(taskManager.tasks[pendingEntry.id]?.status, .pending)

            // Mutate: complete the paused task
            taskManager.completeTask(id: workingEntry.id)
            XCTAssertEqual(taskManager.tasks[workingEntry.id]?.status, .completed)
            XCTAssertNotNil(taskManager.tasks[workingEntry.id]?.completedAt)

            // Mutate: pause the pending task (which sets it to paused with activity date)
            taskManager.pauseTask(id: pendingEntry.id)
            XCTAssertEqual(taskManager.tasks[pendingEntry.id]?.status, .paused)
            XCTAssertNotNil(taskManager.tasks[pendingEntry.id]?.lastActivityAt)
        }
    }

    // MARK: - Session Persistence Tests

    func testTaskPersistenceEntryWithSessionId() throws {
        let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)
        let entryId = UUID()

        let entry = AppStateManager.TaskPersistenceEntry(
            id: entryId,
            name: "Task with session",
            statusRawValue: "working",
            workspacePath: "/Users/test/projects/repo",
            gitBranch: "feature/session",
            sessionId: "session-abc-123",
            createdAt: fixedDate
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AppStateManager.TaskPersistenceEntry.self, from: data)

        XCTAssertEqual(decoded.id, entryId)
        XCTAssertEqual(decoded.name, "Task with session")
        XCTAssertEqual(decoded.statusRawValue, "working")
        XCTAssertEqual(decoded.workspacePath, "/Users/test/projects/repo")
        XCTAssertEqual(decoded.gitBranch, "feature/session")
        XCTAssertEqual(decoded.sessionId, "session-abc-123")
        XCTAssertEqual(decoded.createdAt, fixedDate)
    }

    func testTaskPersistenceEntryWithNilSessionId() throws {
        let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)
        let entryId = UUID()

        let entry = AppStateManager.TaskPersistenceEntry(
            id: entryId,
            name: "Task without session",
            statusRawValue: "pending",
            workspacePath: "/Users/test/projects/repo",
            createdAt: fixedDate
        )

        XCTAssertNil(entry.sessionId)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AppStateManager.TaskPersistenceEntry.self, from: data)

        XCTAssertEqual(decoded.id, entryId)
        XCTAssertEqual(decoded.name, "Task without session")
        XCTAssertNil(decoded.sessionId)
    }

    func testTaskManagerRestorePreservesSessionId() async throws {
        await MainActor.run {
            let taskManager = TaskManager()
            let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)

            let entryWithSession = AppStateManager.TaskPersistenceEntry(
                id: UUID(),
                name: "Task with session",
                statusRawValue: "working",
                workspacePath: "/Users/test/projects/repo1",
                sessionId: "session-xyz-456",
                createdAt: fixedDate
            )

            let entryWithoutSession = AppStateManager.TaskPersistenceEntry(
                id: UUID(),
                name: "Task without session",
                statusRawValue: "completed",
                workspacePath: "/Users/test/projects/repo2",
                createdAt: fixedDate
            )

            taskManager.restoreTasks(from: [entryWithSession, entryWithoutSession])

            XCTAssertEqual(taskManager.tasks.count, 2)

            let restoredWithSession = taskManager.tasks[entryWithSession.id]
            XCTAssertNotNil(restoredWithSession)
            XCTAssertEqual(restoredWithSession?.sessionId, "session-xyz-456")
            XCTAssertEqual(restoredWithSession?.status, .paused) // active -> paused

            let restoredWithoutSession = taskManager.tasks[entryWithoutSession.id]
            XCTAssertNotNil(restoredWithoutSession)
            XCTAssertNil(restoredWithoutSession?.sessionId)
            XCTAssertEqual(restoredWithoutSession?.status, .completed)
        }
    }
}
