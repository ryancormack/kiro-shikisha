import XCTest
@testable import KiroKantoku

final class PixelOfficeTests: XCTestCase {

    // MARK: - CharacterState Mapping Tests

    func testWorkingTaskMapsToWorkingState() {
        XCTAssertEqual(CharacterState.from(taskStatus: .working), .working)
    }

    func testStartingTaskMapsToWorkingState() {
        XCTAssertEqual(CharacterState.from(taskStatus: .starting), .working)
    }

    func testPausedTaskMapsToDrinkingCoffeeState() {
        XCTAssertEqual(CharacterState.from(taskStatus: .paused), .drinkingCoffee)
    }

    func testNeedsAttentionTaskMapsToNeedsInputState() {
        XCTAssertEqual(CharacterState.from(taskStatus: .needsAttention), .needsInput)
    }

    func testPendingTaskMapsToIdleState() {
        XCTAssertEqual(CharacterState.from(taskStatus: .pending), .idle)
    }

    func testCompletedTaskMapsToNil() {
        XCTAssertNil(CharacterState.from(taskStatus: .completed))
    }

    func testFailedTaskMapsToNil() {
        XCTAssertNil(CharacterState.from(taskStatus: .failed))
    }

    func testCancelledTaskMapsToNil() {
        XCTAssertNil(CharacterState.from(taskStatus: .cancelled))
    }

    // MARK: - PixelCharacter Tests

    func testPixelCharacterCreation() {
        let taskId = UUID()
        let character = PixelCharacter(
            taskId: taskId,
            taskName: "Test Task",
            characterIndex: 2,
            positionX: 5.0,
            positionY: 3.0,
            state: .working
        )
        XCTAssertEqual(character.taskId, taskId)
        XCTAssertEqual(character.id, taskId)
        XCTAssertEqual(character.taskName, "Test Task")
        XCTAssertEqual(character.characterIndex, 2)
        XCTAssertEqual(character.positionX, 5.0)
        XCTAssertEqual(character.positionY, 3.0)
        XCTAssertEqual(character.state, .working)
        XCTAssertEqual(character.animationFrame, 0)
    }

    func testPixelCharacterIsAtTarget() {
        var character = PixelCharacter(
            taskId: UUID(),
            taskName: "Test",
            characterIndex: 0,
            positionX: 5.0,
            positionY: 3.0
        )
        // Target defaults to position
        XCTAssertTrue(character.isAtTarget)

        // Move target away
        character.targetX = 10.0
        character.targetY = 7.0
        XCTAssertFalse(character.isAtTarget)

        // Move position close to target
        character.positionX = 9.95
        character.positionY = 6.95
        XCTAssertTrue(character.isAtTarget)
    }

    // MARK: - PixelOfficeViewModel Tests

    func testViewModelCreatesCharactersForWorkingTasks() async throws {
        await MainActor.run {
            let viewModel = PixelOfficeViewModel()
            let task = AgentTask(
                name: "Working task",
                status: .working,
                workspacePath: URL(fileURLWithPath: "/tmp/test")
            )
            viewModel.updateCharacters(from: [task])
            XCTAssertEqual(viewModel.characters.count, 1)
            XCTAssertEqual(viewModel.characters[0].taskId, task.id)
            XCTAssertEqual(viewModel.characters[0].taskName, "Working task")
            XCTAssertEqual(viewModel.characters[0].state, .working)
        }
    }

    func testViewModelCreatesCharactersForPausedTasks() async throws {
        await MainActor.run {
            let viewModel = PixelOfficeViewModel()
            let task = AgentTask(
                name: "Paused task",
                status: .paused,
                workspacePath: URL(fileURLWithPath: "/tmp/test")
            )
            viewModel.updateCharacters(from: [task])
            XCTAssertEqual(viewModel.characters.count, 1)
            XCTAssertEqual(viewModel.characters[0].state, .drinkingCoffee)
        }
    }

    func testViewModelCreatesCharactersForNeedsAttentionTasks() async throws {
        await MainActor.run {
            let viewModel = PixelOfficeViewModel()
            let task = AgentTask(
                name: "Attention task",
                status: .needsAttention,
                workspacePath: URL(fileURLWithPath: "/tmp/test"),
                attentionReason: "Needs approval"
            )
            viewModel.updateCharacters(from: [task])
            XCTAssertEqual(viewModel.characters.count, 1)
            XCTAssertEqual(viewModel.characters[0].state, .needsInput)
        }
    }

    func testViewModelDoesNotCreateCharactersForCompletedTasks() async throws {
        await MainActor.run {
            let viewModel = PixelOfficeViewModel()
            let task = AgentTask(
                name: "Completed task",
                status: .completed,
                workspacePath: URL(fileURLWithPath: "/tmp/test")
            )
            viewModel.updateCharacters(from: [task])
            XCTAssertEqual(viewModel.characters.count, 0)
        }
    }

    func testViewModelDoesNotCreateCharactersForFailedTasks() async throws {
        await MainActor.run {
            let viewModel = PixelOfficeViewModel()
            let task = AgentTask(
                name: "Failed task",
                status: .failed,
                workspacePath: URL(fileURLWithPath: "/tmp/test")
            )
            viewModel.updateCharacters(from: [task])
            XCTAssertEqual(viewModel.characters.count, 0)
        }
    }

    func testViewModelDoesNotCreateCharactersForCancelledTasks() async throws {
        await MainActor.run {
            let viewModel = PixelOfficeViewModel()
            let task = AgentTask(
                name: "Cancelled task",
                status: .cancelled,
                workspacePath: URL(fileURLWithPath: "/tmp/test")
            )
            viewModel.updateCharacters(from: [task])
            XCTAssertEqual(viewModel.characters.count, 0)
        }
    }

    func testViewModelRemovesCharactersWhenTaskCompletes() async throws {
        await MainActor.run {
            let viewModel = PixelOfficeViewModel()
            let task = AgentTask(
                name: "Task that completes",
                status: .working,
                workspacePath: URL(fileURLWithPath: "/tmp/test")
            )
            viewModel.updateCharacters(from: [task])
            XCTAssertEqual(viewModel.characters.count, 1)

            task.status = .completed
            viewModel.updateCharacters(from: [task])
            XCTAssertEqual(viewModel.characters.count, 0)
        }
    }

    func testViewModelHandlesMultipleTasks() async throws {
        await MainActor.run {
            let viewModel = PixelOfficeViewModel()
            let task1 = AgentTask(name: "Task 1", status: .working, workspacePath: URL(fileURLWithPath: "/tmp/t1"))
            let task2 = AgentTask(name: "Task 2", status: .paused, workspacePath: URL(fileURLWithPath: "/tmp/t2"))
            let task3 = AgentTask(name: "Task 3", status: .needsAttention, workspacePath: URL(fileURLWithPath: "/tmp/t3"))
            let task4 = AgentTask(name: "Task 4", status: .completed, workspacePath: URL(fileURLWithPath: "/tmp/t4"))

            viewModel.updateCharacters(from: [task1, task2, task3, task4])
            XCTAssertEqual(viewModel.characters.count, 3) // Only active/paused/attention, not completed
        }
    }

    func testViewModelWorkingTaskGetsAssignedDeskPosition() async throws {
        await MainActor.run {
            let viewModel = PixelOfficeViewModel()
            let task = AgentTask(name: "Working", status: .working, workspacePath: URL(fileURLWithPath: "/tmp/test"))
            viewModel.updateCharacters(from: [task])

            let char = viewModel.characters[0]
            let deskXValues = PixelOfficeConstants.deskPositions.map { Double($0.x) }
            let deskYValues = PixelOfficeConstants.deskPositions.map { Double($0.y) }
            XCTAssertTrue(deskXValues.contains(char.positionX), "Working task should be at a desk X position")
            XCTAssertTrue(deskYValues.contains(char.positionY), "Working task should be at a desk Y position")
        }
    }

    func testViewModelPausedTaskGetsAssignedCoffeePosition() async throws {
        await MainActor.run {
            let viewModel = PixelOfficeViewModel()
            let task = AgentTask(name: "Paused", status: .paused, workspacePath: URL(fileURLWithPath: "/tmp/test"))
            viewModel.updateCharacters(from: [task])

            let char = viewModel.characters[0]
            let coffeeXValues = PixelOfficeConstants.coffeeBarPositions.map { Double($0.x) }
            let coffeeYValues = PixelOfficeConstants.coffeeBarPositions.map { Double($0.y) }
            XCTAssertTrue(coffeeXValues.contains(char.positionX), "Paused task should be at a coffee bar X position")
            XCTAssertTrue(coffeeYValues.contains(char.positionY), "Paused task should be at a coffee bar Y position")
        }
    }

    func testViewModelCharacterIndexIsStableForSameUUID() async throws {
        await MainActor.run {
            let viewModel = PixelOfficeViewModel()
            let uuid = UUID()
            let idx1 = viewModel.characterIndex(for: uuid)
            let idx2 = viewModel.characterIndex(for: uuid)
            XCTAssertEqual(idx1, idx2, "Character index should be deterministic for the same UUID")
        }
    }

    func testViewModelCharacterIndexIsWithinPaletteBounds() async throws {
        await MainActor.run {
            let viewModel = PixelOfficeViewModel()
            for _ in 0..<100 {
                let idx = viewModel.characterIndex(for: UUID())
                XCTAssertGreaterThanOrEqual(idx, 0)
                XCTAssertLessThan(idx, PixelOfficeConstants.characterPalettes.count)
            }
        }
    }

    func testViewModelAdvanceAnimations() async throws {
        await MainActor.run {
            let viewModel = PixelOfficeViewModel()
            let task = AgentTask(name: "Animate", status: .working, workspacePath: URL(fileURLWithPath: "/tmp/test"))
            viewModel.updateCharacters(from: [task])
            XCTAssertEqual(viewModel.characters[0].animationFrame, 0)

            viewModel.advanceAnimations()
            XCTAssertEqual(viewModel.characters[0].animationFrame, 1)

            viewModel.advanceAnimations()
            XCTAssertEqual(viewModel.characters[0].animationFrame, 2)

            viewModel.advanceAnimations()
            XCTAssertEqual(viewModel.characters[0].animationFrame, 3)

            viewModel.advanceAnimations()
            XCTAssertEqual(viewModel.characters[0].animationFrame, 0) // wraps around
        }
    }

    // MARK: - AppSettings Tests

    func testShowPixelOfficeDefaultsToFalse() async throws {
        await MainActor.run {
            let settings = AppSettings()
            XCTAssertFalse(settings.showPixelOffice)
        }
    }

    // MARK: - Constants Tests

    func testDeskPositionsAreWithinOfficeBounds() {
        for pos in PixelOfficeConstants.deskPositions {
            XCTAssertGreaterThanOrEqual(pos.x, 0)
            XCTAssertLessThan(pos.x, PixelOfficeConstants.officeWidth)
            XCTAssertGreaterThanOrEqual(pos.y, 0)
            XCTAssertLessThan(pos.y, PixelOfficeConstants.officeHeight)
        }
    }

    func testCoffeeBarPositionsAreWithinOfficeBounds() {
        for pos in PixelOfficeConstants.coffeeBarPositions {
            XCTAssertGreaterThanOrEqual(pos.x, 0)
            XCTAssertLessThan(pos.x, PixelOfficeConstants.officeWidth)
            XCTAssertGreaterThanOrEqual(pos.y, 0)
            XCTAssertLessThan(pos.y, PixelOfficeConstants.officeHeight)
        }
    }

    func testCharacterPalettesNotEmpty() {
        XCTAssertFalse(PixelOfficeConstants.characterPalettes.isEmpty)
    }

    // MARK: - WaitingForWork State Tests

    func testWaitingForWorkStateMappingWithIdleAgent() {
        XCTAssertEqual(
            CharacterState.from(taskStatus: .working, agentStatus: .idle),
            .waitingForWork
        )
    }

    func testStartingTaskWithIdleAgentMapsToWaitingForWork() {
        XCTAssertEqual(
            CharacterState.from(taskStatus: .starting, agentStatus: .idle),
            .waitingForWork
        )
    }

    func testWorkingTaskWithActiveAgentMapsToWorking() {
        XCTAssertEqual(
            CharacterState.from(taskStatus: .working, agentStatus: .active),
            .working
        )
    }

    func testWorkingTaskWithNilAgentStatusMapsToWorking() {
        XCTAssertEqual(
            CharacterState.from(taskStatus: .working, agentStatus: nil),
            .working
        )
    }

    func testPausedTaskWithIdleAgentMapsToDrinkingCoffee() {
        XCTAssertEqual(
            CharacterState.from(taskStatus: .paused, agentStatus: .idle),
            .drinkingCoffee
        )
    }

    func testCompletedTaskWithAgentStatusMapsToNil() {
        XCTAssertNil(
            CharacterState.from(taskStatus: .completed, agentStatus: .idle)
        )
    }

    func testViewModelWaitingForWorkWithAgentStatuses() async throws {
        await MainActor.run {
            let viewModel = PixelOfficeViewModel()
            let task = AgentTask(
                name: "Waiting task",
                status: .working,
                workspacePath: URL(fileURLWithPath: "/tmp/test")
            )
            let agentStatuses: [UUID: AgentStatus] = [task.id: .idle]
            viewModel.updateCharacters(from: [task], agentStatuses: agentStatuses)
            XCTAssertEqual(viewModel.characters.count, 1)
            XCTAssertEqual(viewModel.characters[0].state, .waitingForWork)
        }
    }

    func testViewModelWorkingWithActiveAgentStatus() async throws {
        await MainActor.run {
            let viewModel = PixelOfficeViewModel()
            let task = AgentTask(
                name: "Active task",
                status: .working,
                workspacePath: URL(fileURLWithPath: "/tmp/test")
            )
            let agentStatuses: [UUID: AgentStatus] = [task.id: .active]
            viewModel.updateCharacters(from: [task], agentStatuses: agentStatuses)
            XCTAssertEqual(viewModel.characters.count, 1)
            XCTAssertEqual(viewModel.characters[0].state, .working)
        }
    }
}
