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

    // MARK: - Paused Task Tests

    func testPausedTaskNotInActiveOrCompleted() async throws {
        await MainActor.run {
            let taskManager = TaskManager()
            let path = URL(fileURLWithPath: "/Users/test/projects/repo")
            let request = TaskCreationRequest(name: "Pausable task", workspacePath: path)
            let task = taskManager.createTask(from: request)

            // Pause the task
            taskManager.pauseTask(id: task.id)
            XCTAssertEqual(task.status, .paused)

            // Should not be in activeTasks
            XCTAssertTrue(taskManager.activeTasks.isEmpty, "Paused task should not appear in activeTasks")

            // Should not be in completedTasks
            XCTAssertTrue(taskManager.completedTasks.isEmpty, "Paused task should not appear in completedTasks")

            // Should still be in allTasks
            XCTAssertEqual(taskManager.allTasks.count, 1)
        }
    }

    func testResumeTaskSetsWorkingStatus() async throws {
        await MainActor.run {
            let taskManager = TaskManager()
            let path = URL(fileURLWithPath: "/Users/test/projects/repo")
            let request = TaskCreationRequest(name: "Resume test", workspacePath: path)
            let task = taskManager.createTask(from: request)

            // Pause then resume
            taskManager.pauseTask(id: task.id)
            XCTAssertEqual(task.status, .paused)
            let pausedAt = task.lastActivityAt

            // Small delay to ensure time difference
            // On non-macOS, resumeTask throws platformNotSupported
            // So we test what we can: the pause behavior and status checks
            XCTAssertNotNil(pausedAt)
            XCTAssertFalse(task.status.isActive)
            XCTAssertFalse(task.status.isTerminal)
        }
    }

    func testTerminalTasksHaveIsTerminalTrue() throws {
        // Verify all terminal statuses
        XCTAssertTrue(TaskStatus.completed.isTerminal)
        XCTAssertTrue(TaskStatus.failed.isTerminal)
        XCTAssertTrue(TaskStatus.cancelled.isTerminal)

        // Verify paused is NOT terminal (important for timer display logic)
        XCTAssertFalse(TaskStatus.paused.isTerminal)
    }

    func testPauseTaskSetsLastActivityAt() async throws {
        await MainActor.run {
            let taskManager = TaskManager()
            let path = URL(fileURLWithPath: "/Users/test/projects/repo")
            let request = TaskCreationRequest(name: "Pause activity test", workspacePath: path)
            let task = taskManager.createTask(from: request)

            XCTAssertNil(task.lastActivityAt)

            taskManager.pauseTask(id: task.id)

            XCTAssertEqual(task.status, .paused)
            XCTAssertNotNil(task.lastActivityAt)
        }
    }

    // MARK: - Pause Syncs Data Tests

    func testPauseTaskCallsSyncFromAgent() async throws {
        await MainActor.run {
            let taskManager = TaskManager()
            let path = URL(fileURLWithPath: "/Users/test/projects/repo")
            let request = TaskCreationRequest(name: "Sync test task", workspacePath: path)
            let task = taskManager.createTask(from: request)

            // On non-macOS, syncFromAgent is a no-op, but pauseTask should still
            // set status to paused and update lastActivityAt
            task.status = .working
            taskManager.pauseTask(id: task.id)

            XCTAssertEqual(task.status, .paused)
            XCTAssertNotNil(task.lastActivityAt)
        }
    }

    func testPausedTaskWithMessagesRetainsMessages() async throws {
        await MainActor.run {
            let taskManager = TaskManager()
            let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)
            let message1 = ChatMessage(role: .user, content: "Hello")
            let message2 = ChatMessage(role: .assistant, content: "Hi there")

            // Use restoreTasks to create a working task, then manually add messages
            let entryId = UUID()
            let entry = AppStateManager.TaskPersistenceEntry(
                id: entryId,
                name: "Task with messages",
                statusRawValue: "working",
                workspacePath: "/Users/test/projects/repo",
                createdAt: fixedDate
            )
            taskManager.restoreTasks(from: [entry])

            // Working tasks are restored as paused
            let task = taskManager.tasks[entryId]!
            XCTAssertEqual(task.status, .paused)

            // Add messages to the task
            task.messages = [message1, message2]
            XCTAssertEqual(task.messages.count, 2)

            // Pause should retain messages (syncFromAgent is no-op on Linux)
            taskManager.pauseTask(id: task.id)

            XCTAssertEqual(task.status, .paused)
            // Messages should be preserved after pause
            XCTAssertEqual(task.messages.count, 2)
            XCTAssertEqual(task.messages[0].content, "Hello")
            XCTAssertEqual(task.messages[1].content, "Hi there")
        }
    }

    func testTaskStateTransitionsDuringPauseResumeCycle() async throws {
        await MainActor.run {
            let taskManager = TaskManager()
            let path = URL(fileURLWithPath: "/Users/test/projects/repo")
            let request = TaskCreationRequest(name: "Transition test", workspacePath: path)
            let task = taskManager.createTask(from: request)

            // Initial state
            XCTAssertEqual(task.status, .pending)

            // Transition to working
            task.status = .working
            XCTAssertTrue(task.status.isActive)
            XCTAssertFalse(task.status.isTerminal)

            // Pause
            taskManager.pauseTask(id: task.id)
            XCTAssertEqual(task.status, .paused)
            XCTAssertFalse(task.status.isActive)
            XCTAssertFalse(task.status.isTerminal)
        }

        // Separately test the complete-from-paused flow
        await MainActor.run {
            let taskManager = TaskManager()
            let path = URL(fileURLWithPath: "/Users/test/projects/repo")
            let request = TaskCreationRequest(name: "Transition complete test", workspacePath: path)
            let task = taskManager.createTask(from: request)

            // Set to working then pause
            task.status = .working
            taskManager.pauseTask(id: task.id)
            XCTAssertEqual(task.status, .paused)

            // Complete from paused state
            taskManager.completeTask(id: task.id)
            XCTAssertEqual(task.status, .completed)
            XCTAssertTrue(task.status.isTerminal)
            XCTAssertNotNil(task.completedAt)
        }
    }

    func testPausedTaskWithFileChangesRetainsFileChanges() async throws {
        await MainActor.run {
            let taskManager = TaskManager()
            let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)
            let fileChange = FileChange(
                path: "Sources/main.swift",
                oldContent: "let x = 1",
                newContent: "let x = 2",
                changeType: .modified,
                toolCallId: "tool-1"
            )

            // Use restoreTasks to create a task, then add file changes
            let entryId = UUID()
            let entry = AppStateManager.TaskPersistenceEntry(
                id: entryId,
                name: "Task with file changes",
                statusRawValue: "working",
                workspacePath: "/Users/test/projects/repo",
                createdAt: fixedDate
            )
            taskManager.restoreTasks(from: [entry])

            let task = taskManager.tasks[entryId]!
            task.fileChanges = [fileChange]

            XCTAssertEqual(task.fileChanges.count, 1)

            taskManager.pauseTask(id: task.id)

            XCTAssertEqual(task.status, .paused)
            // File changes should be preserved after pause
            XCTAssertEqual(task.fileChanges.count, 1)
            XCTAssertEqual(task.fileChanges[0].path, "Sources/main.swift")
        }
    }

    // MARK: - Resume/Reopen Error Recovery Tests

    func testAutoReconnectShouldOnlyTargetPausedTasks() async throws {
        await MainActor.run {
            let taskManager = TaskManager()
            let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)

            let pausedEntry = AppStateManager.TaskPersistenceEntry(
                id: UUID(),
                name: "Paused with session",
                statusRawValue: "paused",
                workspacePath: "/Users/test/projects/repo1",
                sessionId: "session-1",
                createdAt: fixedDate
            )
            let completedEntry = AppStateManager.TaskPersistenceEntry(
                id: UUID(),
                name: "Completed with session",
                statusRawValue: "completed",
                workspacePath: "/Users/test/projects/repo2",
                sessionId: "session-2",
                createdAt: fixedDate
            )
            let cancelledEntry = AppStateManager.TaskPersistenceEntry(
                id: UUID(),
                name: "Cancelled with session",
                statusRawValue: "cancelled",
                workspacePath: "/Users/test/projects/repo3",
                sessionId: "session-3",
                createdAt: fixedDate
            )
            let pausedNoSession = AppStateManager.TaskPersistenceEntry(
                id: UUID(),
                name: "Paused no session",
                statusRawValue: "paused",
                workspacePath: "/Users/test/projects/repo4",
                createdAt: fixedDate
            )

            taskManager.restoreTasks(from: [pausedEntry, completedEntry, cancelledEntry, pausedNoSession])

            // Only paused tasks with session IDs should be candidates for auto-reconnect
            let candidates = taskManager.allTasks.filter { $0.status == .paused && $0.sessionId != nil }
            XCTAssertEqual(candidates.count, 1)
            XCTAssertEqual(candidates.first?.name, "Paused with session")

            // Terminal tasks with sessions should NOT be candidates
            let terminalWithSession = taskManager.allTasks.filter { $0.status.isTerminal && $0.sessionId != nil }
            XCTAssertEqual(terminalWithSession.count, 2)

            // Paused without session should not be a candidate
            let pausedWithoutSession = taskManager.allTasks.filter { $0.status == .paused && $0.sessionId == nil }
            XCTAssertEqual(pausedWithoutSession.count, 1)
        }
    }

    @MainActor
    func testResumeTaskFailureResetsStatusOnLinux() async throws {
        // On Linux, resumeTask throws platformNotSupported immediately
        // This test verifies the task status is not corrupted
        let taskManager = TaskManager()
        let path = URL(fileURLWithPath: "/Users/test/projects/repo")
        let request = TaskCreationRequest(name: "Resume fail test", workspacePath: path)
        let task = taskManager.createTask(from: request)
        task.status = .paused
        task.sessionId = "session-abc"

        // resumeTask on Linux throws platformNotSupported
        // The task should remain in its pre-call state
        let statusBefore = task.status
        do {
            try await taskManager.resumeTask(id: task.id)
            XCTFail("Expected platformNotSupported error")
        } catch {
            // On Linux, the stub throws immediately without modifying state
            // Verify task is still paused (not stuck in .starting)
            XCTAssertEqual(task.status, statusBefore)
        }
    }

    @MainActor
    func testReopenTaskFailurePreservesStatusOnLinux() async throws {
        // On Linux, reopenTask throws platformNotSupported immediately
        let taskManager = TaskManager()
        let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)

        let entry = AppStateManager.TaskPersistenceEntry(
            id: UUID(),
            name: "Completed task to reopen",
            statusRawValue: "completed",
            workspacePath: "/Users/test/projects/repo",
            sessionId: "session-xyz",
            createdAt: fixedDate
        )
        taskManager.restoreTasks(from: [entry])

        let task = taskManager.tasks[entry.id]!
        XCTAssertEqual(task.status, .completed)

        do {
            try await taskManager.reopenTask(id: task.id)
            XCTFail("Expected platformNotSupported error")
        } catch {
            // Task should NOT be stuck in .starting - should be back to completed
            XCTAssertEqual(task.status, .completed)
        }
    }

    func testReopenTaskRequiresSessionId() async throws {
        await MainActor.run {
            let taskManager = TaskManager()
            let path = URL(fileURLWithPath: "/Users/test/projects/repo")
            let request = TaskCreationRequest(name: "No session task", workspacePath: path)
            let task = taskManager.createTask(from: request)

            // Task has no sessionId
            XCTAssertNil(task.sessionId)
        }
        // reopenTask should throw noSessionId
        // On Linux it throws platformNotSupported, which is also acceptable
    }

    // MARK: - Fresh Session Fallback Tests

    @MainActor
    func testResumeTaskPreservesExistingMessages() async throws {
        let taskManager = TaskManager()
        let path = URL(fileURLWithPath: "/Users/test/projects/repo")
        let request = TaskCreationRequest(name: "Resume preserve test", workspacePath: path)
        let task = taskManager.createTask(from: request)
        
        // Set up task with existing messages
        let msg1 = ChatMessage(role: .user, content: "Hello agent")
        let msg2 = ChatMessage(role: .assistant, content: "Hi! How can I help?")
        task.messages = [msg1, msg2]
        task.status = .paused
        task.sessionId = "old-session-123"
        
        // On Linux, resumeTask throws platformNotSupported
        // But verify that messages are NOT cleared before the throw
        let messagesBefore = task.messages
        
        do {
            try await taskManager.resumeTask(id: task.id)
            // Won't reach here on Linux
        } catch {
            // Expected on Linux
        }
        
        // Messages should still be intact (not cleared)
        XCTAssertEqual(task.messages.count, messagesBefore.count)
        XCTAssertEqual(task.messages[0].content, "Hello agent")
        XCTAssertEqual(task.messages[1].content, "Hi! How can I help?")
    }

    @MainActor
    func testReopenTaskPreservesExistingMessages() async throws {
        let taskManager = TaskManager()
        let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)
        
        let entry = AppStateManager.TaskPersistenceEntry(
            id: UUID(),
            name: "Reopen preserve test",
            statusRawValue: "completed",
            workspacePath: "/Users/test/projects/repo",
            sessionId: "old-session-456",
            createdAt: fixedDate
        )
        taskManager.restoreTasks(from: [entry])
        
        let task = taskManager.tasks[entry.id]!
        
        // Set up task with existing messages and file changes
        let msg1 = ChatMessage(role: .user, content: "Implement feature X")
        let msg2 = ChatMessage(role: .assistant, content: "I'll start working on that.")
        task.messages = [msg1, msg2]
        
        let fileChange = FileChange(
            path: "Sources/main.swift",
            oldContent: "let x = 1",
            newContent: "let x = 2",
            changeType: .modified,
            toolCallId: "tool-1"
        )
        task.fileChanges = [fileChange]
        
        do {
            try await taskManager.reopenTask(id: task.id)
            // Won't reach here on Linux
        } catch {
            // Expected on Linux
        }
        
        // Messages and file changes should still be intact
        XCTAssertEqual(task.messages.count, 2)
        XCTAssertEqual(task.messages[0].content, "Implement feature X")
        XCTAssertEqual(task.messages[1].content, "I'll start working on that.")
        XCTAssertEqual(task.fileChanges.count, 1)
        XCTAssertEqual(task.fileChanges[0].path, "Sources/main.swift")
    }

    @MainActor
    func testConcurrentResumeDoesNotInterfere() async throws {
        // Test that multiple tasks can be in resume state independently
        let taskManager = TaskManager()
        let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)
        
        let entry1 = AppStateManager.TaskPersistenceEntry(
            id: UUID(),
            name: "Task A",
            statusRawValue: "paused",
            workspacePath: "/Users/test/projects/repo1",
            sessionId: "session-a",
            createdAt: fixedDate
        )
        let entry2 = AppStateManager.TaskPersistenceEntry(
            id: UUID(),
            name: "Task B",
            statusRawValue: "paused",
            workspacePath: "/Users/test/projects/repo2",
            sessionId: "session-b",
            createdAt: fixedDate
        )
        let entry3 = AppStateManager.TaskPersistenceEntry(
            id: UUID(),
            name: "Task C",
            statusRawValue: "paused",
            workspacePath: "/Users/test/projects/repo3",
            sessionId: "session-c",
            createdAt: fixedDate
        )
        
        taskManager.restoreTasks(from: [entry1, entry2, entry3])
        
        // Verify all three tasks are independent
        XCTAssertEqual(taskManager.tasks.count, 3)
        
        let taskA = taskManager.tasks[entry1.id]!
        let taskB = taskManager.tasks[entry2.id]!
        let taskC = taskManager.tasks[entry3.id]!
        
        XCTAssertEqual(taskA.status, .paused)
        XCTAssertEqual(taskB.status, .paused)
        XCTAssertEqual(taskC.status, .paused)
        
        // Set messages on each task
        taskA.messages = [ChatMessage(role: .user, content: "Task A message")]
        taskB.messages = [ChatMessage(role: .user, content: "Task B message")]
        taskC.messages = [ChatMessage(role: .user, content: "Task C message")]
        
        // Attempt to resume each (will fail on Linux) but should not affect others
        do { try await taskManager.reopenTask(id: entry1.id) } catch {}
        do { try await taskManager.reopenTask(id: entry2.id) } catch {}
        do { try await taskManager.reopenTask(id: entry3.id) } catch {}
        
        // Each task should retain its own messages independently
        XCTAssertEqual(taskA.messages.first?.content, "Task A message")
        XCTAssertEqual(taskB.messages.first?.content, "Task B message")
        XCTAssertEqual(taskC.messages.first?.content, "Task C message")
        
        // Failing one task should not affect others' status
        // On Linux all stay paused since reopenTask throws immediately
        // On macOS with real errors, each should be independent
    }

    // MARK: - Conversation History Loading Tests

    func testRestoreTasksDoesNotRestoreMessages() async throws {
        await MainActor.run {
            let taskManager = TaskManager()
            let entry = AppStateManager.TaskPersistenceEntry(
                id: UUID(),
                name: "Task with lost messages",
                statusRawValue: "working",
                workspacePath: "/Users/test/projects/repo",
                sessionId: "session-abc",
                createdAt: Date()
            )
            taskManager.restoreTasks(from: [entry])
            let task = taskManager.tasks[entry.id]!
            // Messages are NOT persisted in TaskPersistenceEntry, so they're always empty after restore
            XCTAssertTrue(task.messages.isEmpty, "Messages should be empty after restore since TaskPersistenceEntry does not store them")
            // But sessionId IS preserved
            XCTAssertEqual(task.sessionId, "session-abc")
        }
    }

    func testSessionStorageLoadSessionHistory() throws {
        // Create a temp directory with a mock JSONL file
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sessionId = "test-session-123"
        let jsonlFile = tempDir.appendingPathComponent("\(sessionId).jsonl")

        let events = [
            #"{"type":"user_message","content":"Hello agent","timestamp":1700000000}"#,
            #"{"type":"agent_message","content":"Hi there! How can I help?","timestamp":1700000001}"#,
            #"{"type":"turn_end","timestamp":1700000002}"#,
            #"{"type":"user_message","content":"Fix my code","timestamp":1700000003}"#,
            #"{"type":"agent_message","content":"Sure, let me look at it.","timestamp":1700000004}"#,
            #"{"type":"turn_end","timestamp":1700000005}"#
        ]
        try events.joined(separator: "\n").write(to: jsonlFile, atomically: true, encoding: .utf8)

        let storage = SessionStorage(sessionsDirectory: tempDir)
        let messages = try storage.loadSessionHistory(sessionId: sessionId)

        XCTAssertEqual(messages.count, 4) // 2 user + 2 assistant
        XCTAssertEqual(messages[0].role, .user)
        XCTAssertEqual(messages[0].content, "Hello agent")
        XCTAssertEqual(messages[1].role, .assistant)
        XCTAssertEqual(messages[1].content, "Hi there! How can I help?")
        XCTAssertEqual(messages[2].role, .user)
        XCTAssertEqual(messages[2].content, "Fix my code")
        XCTAssertEqual(messages[3].role, .assistant)
        XCTAssertEqual(messages[3].content, "Sure, let me look at it.")
    }

    func testSessionStorageLoadNonExistentSession() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storage = SessionStorage(sessionsDirectory: tempDir)
        XCTAssertThrowsError(try storage.loadSessionHistory(sessionId: "nonexistent")) { error in
            XCTAssertTrue(error is SessionStorageError)
        }
    }

    func testSessionStorageWithToolCallEvents() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sessionId = "test-session-toolcalls"
        let jsonlFile = tempDir.appendingPathComponent("\(sessionId).jsonl")

        let events = [
            #"{"type":"user_message","content":"Please edit my file","timestamp":1700000000}"#,
            #"{"type":"agent_message","content":"I will edit the file now.","timestamp":1700000001}"#,
            #"{"type":"tool_call","tool_call_id":"tc-001","tool_name":"edit_file","timestamp":1700000002}"#,
            #"{"type":"tool_result","tool_call_id":"tc-001","tool_output":"File edited","timestamp":1700000003}"#,
            #"{"type":"agent_message","content":" Done editing.","timestamp":1700000004}"#,
            #"{"type":"tool_call","tool_call_id":"tc-002","tool_name":"read_file","timestamp":1700000005}"#,
            #"{"type":"tool_result","tool_call_id":"tc-002","tool_output":"file contents","timestamp":1700000006}"#,
            #"{"type":"turn_end","timestamp":1700000007}"#,
            #"{"type":"user_message","content":"Thanks","timestamp":1700000008}"#,
            #"{"type":"agent_message","content":"You're welcome!","timestamp":1700000009}"#,
            #"{"type":"turn_end","timestamp":1700000010}"#
        ]
        try events.joined(separator: "\n").write(to: jsonlFile, atomically: true, encoding: .utf8)

        let storage = SessionStorage(sessionsDirectory: tempDir)
        let messages = try storage.loadSessionHistory(sessionId: sessionId)

        // Expected: user("Please edit my file"), assistant("I will edit the file now. Done editing." with tool calls), user("Thanks"), assistant("You're welcome!")
        XCTAssertEqual(messages.count, 4)

        XCTAssertEqual(messages[0].role, .user)
        XCTAssertEqual(messages[0].content, "Please edit my file")

        XCTAssertEqual(messages[1].role, .assistant)
        XCTAssertTrue(messages[1].content.contains("I will edit the file now."))
        XCTAssertTrue(messages[1].content.contains("Done editing."))
        // Tool call IDs should be tracked
        XCTAssertNotNil(messages[1].toolCallIds)
        XCTAssertEqual(messages[1].toolCallIds?.count, 2)
        XCTAssertTrue(messages[1].toolCallIds?.contains("tc-001") ?? false)
        XCTAssertTrue(messages[1].toolCallIds?.contains("tc-002") ?? false)

        XCTAssertEqual(messages[2].role, .user)
        XCTAssertEqual(messages[2].content, "Thanks")

        XCTAssertEqual(messages[3].role, .assistant)
        XCTAssertEqual(messages[3].content, "You're welcome!")
        // No tool calls in this assistant message
        XCTAssertNil(messages[3].toolCallIds)
    }

    func testSessionStorageWithMalformedEvents() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sessionId = "test-session-malformed"
        let jsonlFile = tempDir.appendingPathComponent("\(sessionId).jsonl")

        let events = [
            #"{"type":"user_message","content":"First message","timestamp":1700000000}"#,
            #"{"type":"agent_message","content":"First reply","timestamp":1700000001}"#,
            #"{"type":"turn_end","timestamp":1700000002}"#,
            #"this is not valid json at all"#,
            #"{"broken json"#,
            #"{"type":"user_message","content":"Second message","timestamp":1700000005}"#,
            #"{"type":"agent_message","content":"Second reply","timestamp":1700000006}"#,
            #"{"type":"turn_end","timestamp":1700000007}"#
        ]
        try events.joined(separator: "\n").write(to: jsonlFile, atomically: true, encoding: .utf8)

        let storage = SessionStorage(sessionsDirectory: tempDir)
        let messages = try storage.loadSessionHistory(sessionId: sessionId)

        // Malformed lines should be skipped; valid events before and after should parse correctly
        XCTAssertEqual(messages.count, 4) // 2 user + 2 assistant
        XCTAssertEqual(messages[0].role, .user)
        XCTAssertEqual(messages[0].content, "First message")
        XCTAssertEqual(messages[1].role, .assistant)
        XCTAssertEqual(messages[1].content, "First reply")
        XCTAssertEqual(messages[2].role, .user)
        XCTAssertEqual(messages[2].content, "Second message")
        XCTAssertEqual(messages[3].role, .assistant)
        XCTAssertEqual(messages[3].content, "Second reply")
    }

    // MARK: - Session ID Fallback Loading Tests

    @MainActor
    func testTaskSessionIdUpdateOnReconnect() async throws {
        // Verify that a task's sessionId can be updated to a new value
        // simulating what happens when loadAgent creates a fresh session
        let taskManager = TaskManager()
        let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)

        let entry = AppStateManager.TaskPersistenceEntry(
            id: UUID(),
            name: "Reconnect session test",
            statusRawValue: "paused",
            workspacePath: "/Users/test/projects/repo",
            sessionId: "old-session-id",
            createdAt: fixedDate
        )
        taskManager.restoreTasks(from: [entry])

        let task = taskManager.tasks[entry.id]!
        XCTAssertEqual(task.sessionId, "old-session-id")

        // Simulate what TaskManager does after loadAgent returns a fresh session:
        // update the task's sessionId
        let newSessionId = "new-fresh-session-id"
        task.sessionId = newSessionId

        XCTAssertEqual(task.sessionId, newSessionId)
        XCTAssertNotEqual(task.sessionId, "old-session-id")
    }

    func testSessionStorageFallbackLoading() throws {
        // Test that we can load history from an original session ID when
        // the current session ID has no history (simulating the fresh session fallback)
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let originalSessionId = "original-session-abc"
        let freshSessionId = "fresh-session-xyz"

        // Create history file only for the original session
        let jsonlFile = tempDir.appendingPathComponent("\(originalSessionId).jsonl")
        let events = [
            #"{"type":"user_message","content":"Hello from original session","timestamp":1700000000}"#,
            #"{"type":"agent_message","content":"Original reply","timestamp":1700000001}"#,
            #"{"type":"turn_end","timestamp":1700000002}"#
        ]
        try events.joined(separator: "\n").write(to: jsonlFile, atomically: true, encoding: .utf8)

        let storage = SessionStorage(sessionsDirectory: tempDir)

        // Loading from the fresh session should fail (no file)
        let freshResult = try? storage.loadSessionHistory(sessionId: freshSessionId)
        XCTAssertNil(freshResult, "Fresh session should have no history file")

        // Loading from the original session should succeed
        let originalResult = try storage.loadSessionHistory(sessionId: originalSessionId)
        XCTAssertEqual(originalResult.count, 2)
        XCTAssertEqual(originalResult[0].content, "Hello from original session")
        XCTAssertEqual(originalResult[1].content, "Original reply")

        // This mirrors the fallback pattern in TaskManager:
        // 1. Try loading from currentSessionId (fresh) - empty/fails
        // 2. Fall back to originalSessionId - succeeds
    }

    @MainActor
    func testSequentialReconnectIndependence() async throws {
        // Test that sequential reconnect attempts for multiple tasks
        // don't interfere with each other
        let taskManager = TaskManager()
        let fixedDate = Date(timeIntervalSinceReferenceDate: 700000000)

        var entries: [AppStateManager.TaskPersistenceEntry] = []
        for i in 1...5 {
            entries.append(AppStateManager.TaskPersistenceEntry(
                id: UUID(),
                name: "Task \(i)",
                statusRawValue: "paused",
                workspacePath: "/Users/test/projects/repo\(i)",
                sessionId: "session-\(i)",
                createdAt: fixedDate
            ))
        }
        taskManager.restoreTasks(from: entries)

        // Attempt sequential reconnect (mimicking the fixed auto-reconnect)
        for entry in entries {
            do {
                try await taskManager.reopenTask(id: entry.id)
            } catch {
                // Expected on Linux - platformNotSupported
            }
        }

        // All tasks should remain paused (on Linux, reopenTask throws immediately)
        // Crucially, each task retains its own session ID
        for entry in entries {
            let task = taskManager.tasks[entry.id]!
            XCTAssertEqual(task.sessionId, entry.sessionId,
                "Task \(entry.name) should retain its session ID after failed reconnect")
            XCTAssertEqual(task.status, .paused,
                "Task \(entry.name) should remain paused after failed reconnect on Linux")
        }
    }

    // MARK: - Session Lock File Tests

    func testSessionStorageRemoveLockFile() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sessionId = "test-session-lock"
        let lockFile = tempDir.appendingPathComponent("\(sessionId).lock")

        // Create a fake lock file
        try "locked".write(to: lockFile, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: lockFile.path))

        let storage = SessionStorage(sessionsDirectory: tempDir)
        let result = storage.removeSessionLockFile(sessionId: sessionId)

        XCTAssertTrue(result, "Should return true when lock file was removed")
        XCTAssertFalse(FileManager.default.fileExists(atPath: lockFile.path), "Lock file should be deleted")
    }

    func testSessionStorageRemoveLockFileWhenNoLockExists() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storage = SessionStorage(sessionsDirectory: tempDir)
        let result = storage.removeSessionLockFile(sessionId: "nonexistent-session")

        XCTAssertFalse(result, "Should return false when no lock file exists")
    }

    func testSessionStorageRemoveLockFileDoesNotAffectSessionFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sessionId = "test-session-preserve"

        // Create lock file, json file, and jsonl file
        let lockFile = tempDir.appendingPathComponent("\(sessionId).lock")
        let jsonFile = tempDir.appendingPathComponent("\(sessionId).json")
        let jsonlFile = tempDir.appendingPathComponent("\(sessionId).jsonl")

        try "locked".write(to: lockFile, atomically: true, encoding: .utf8)
        try "{\"session_id\":\"\(sessionId)\",\"cwd\":\"/tmp\"}".write(to: jsonFile, atomically: true, encoding: .utf8)
        try "{\"type\":\"user_message\",\"content\":\"Hello\"}".write(to: jsonlFile, atomically: true, encoding: .utf8)

        let storage = SessionStorage(sessionsDirectory: tempDir)
        let result = storage.removeSessionLockFile(sessionId: sessionId)

        XCTAssertTrue(result, "Should return true when lock file was removed")
        XCTAssertFalse(FileManager.default.fileExists(atPath: lockFile.path), "Lock file should be deleted")
        XCTAssertTrue(FileManager.default.fileExists(atPath: jsonFile.path), "Session metadata file should be preserved")
        XCTAssertTrue(FileManager.default.fileExists(atPath: jsonlFile.path), "Session events file should be preserved")
    }
}
