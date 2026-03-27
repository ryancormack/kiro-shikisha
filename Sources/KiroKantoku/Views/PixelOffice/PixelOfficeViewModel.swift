import Foundation
#if canImport(Observation)
import Observation
#endif

#if canImport(Observation)
@Observable
@MainActor
public final class PixelOfficeViewModel {
    public var characters: [PixelCharacter] = []
    private var deskAssignments: [UUID: Int] = [:]
    private var coffeeAssignments: [UUID: Int] = [:]

    public init() {}

    /// Updates characters based on current task list
    public func updateCharacters(from tasks: [AgentTask]) {
        let relevantTasks = tasks.filter { CharacterState.from(taskStatus: $0.status) != nil }
        let relevantIds = Set(relevantTasks.map { $0.id })
        let existingIds = Set(characters.map { $0.taskId })

        // Remove characters for tasks that are no longer relevant
        let removedIds = existingIds.subtracting(relevantIds)
        for id in removedIds {
            deskAssignments.removeValue(forKey: id)
            coffeeAssignments.removeValue(forKey: id)
        }
        characters.removeAll { removedIds.contains($0.taskId) }

        // Add or update characters
        for task in relevantTasks {
            guard let targetState = CharacterState.from(taskStatus: task.status) else { continue }

            if let index = characters.firstIndex(where: { $0.taskId == task.id }) {
                // Update existing character
                let (tx, ty) = targetPosition(for: task.id, state: targetState)
                characters[index].taskName = task.name
                characters[index].targetX = tx
                characters[index].targetY = ty

                if characters[index].isAtTarget {
                    characters[index].state = targetState
                } else {
                    characters[index].state = .walking
                }

                // Update assignments if state changed
                if targetState == .drinkingCoffee {
                    deskAssignments.removeValue(forKey: task.id)
                    if coffeeAssignments[task.id] == nil {
                        coffeeAssignments[task.id] = nextAvailableCoffeeSpot()
                    }
                } else {
                    coffeeAssignments.removeValue(forKey: task.id)
                    if deskAssignments[task.id] == nil {
                        deskAssignments[task.id] = nextAvailableDesk()
                    }
                }
            } else {
                // Create new character
                let charIndex = characterIndex(for: task.id)

                // Assign position
                if targetState == .drinkingCoffee {
                    coffeeAssignments[task.id] = nextAvailableCoffeeSpot()
                } else {
                    deskAssignments[task.id] = nextAvailableDesk()
                }

                let (px, py) = targetPosition(for: task.id, state: targetState)
                let character = PixelCharacter(
                    taskId: task.id,
                    taskName: task.name,
                    characterIndex: charIndex,
                    positionX: px,
                    positionY: py,
                    state: targetState
                )
                characters.append(character)
            }
        }
    }

    /// Updates characters based on current task list with agent status information
    public func updateCharacters(from tasks: [AgentTask], agentStatuses: [UUID: AgentStatus]) {
        let relevantTasks = tasks.filter { CharacterState.from(taskStatus: $0.status, agentStatus: agentStatuses[$0.id]) != nil }
        let relevantIds = Set(relevantTasks.map { $0.id })
        let existingIds = Set(characters.map { $0.taskId })

        // Remove characters for tasks that are no longer relevant
        let removedIds = existingIds.subtracting(relevantIds)
        for id in removedIds {
            deskAssignments.removeValue(forKey: id)
            coffeeAssignments.removeValue(forKey: id)
        }
        characters.removeAll { removedIds.contains($0.taskId) }

        // Add or update characters
        for task in relevantTasks {
            guard let targetState = CharacterState.from(taskStatus: task.status, agentStatus: agentStatuses[task.id]) else { continue }

            if let index = characters.firstIndex(where: { $0.taskId == task.id }) {
                // Update existing character
                let (tx, ty) = targetPosition(for: task.id, state: targetState)
                characters[index].taskName = task.name
                characters[index].targetX = tx
                characters[index].targetY = ty

                if characters[index].isAtTarget {
                    characters[index].state = targetState
                } else {
                    characters[index].state = .walking
                }

                // Update assignments if state changed
                if targetState == .drinkingCoffee {
                    deskAssignments.removeValue(forKey: task.id)
                    if coffeeAssignments[task.id] == nil {
                        coffeeAssignments[task.id] = nextAvailableCoffeeSpot()
                    }
                } else {
                    coffeeAssignments.removeValue(forKey: task.id)
                    if deskAssignments[task.id] == nil {
                        deskAssignments[task.id] = nextAvailableDesk()
                    }
                }
            } else {
                // Create new character
                let charIndex = characterIndex(for: task.id)

                // Assign position
                if targetState == .drinkingCoffee {
                    coffeeAssignments[task.id] = nextAvailableCoffeeSpot()
                } else {
                    deskAssignments[task.id] = nextAvailableDesk()
                }

                let (px, py) = targetPosition(for: task.id, state: targetState)
                let character = PixelCharacter(
                    taskId: task.id,
                    taskName: task.name,
                    characterIndex: charIndex,
                    positionX: px,
                    positionY: py,
                    state: targetState
                )
                characters.append(character)
            }
        }
    }

    /// Advance character positions toward their targets
    public func moveCharactersTowardTargets() {
        let speed = PixelOfficeConstants.moveSpeed
        for i in characters.indices {
            if !characters[i].isAtTarget {
                let dx = characters[i].targetX - characters[i].positionX
                let dy = characters[i].targetY - characters[i].positionY
                let dist = (dx * dx + dy * dy).squareRoot()
                if dist < speed {
                    characters[i].positionX = characters[i].targetX
                    characters[i].positionY = characters[i].targetY
                } else {
                    characters[i].positionX += (dx / dist) * speed
                    characters[i].positionY += (dy / dist) * speed
                }

                if characters[i].isAtTarget {
                    characters[i].state = .idle
                }
            }
        }
    }

    /// Advance animation frames
    public func advanceAnimations() {
        for i in characters.indices {
            characters[i].animationFrame = (characters[i].animationFrame + 1) % 4
        }
    }

    /// Get a stable character index from a task UUID
    public func characterIndex(for taskId: UUID) -> Int {
        let hash = taskId.uuidString.hashValue
        let count = PixelOfficeConstants.characterPalettes.count
        return abs(hash % count)
    }

    // MARK: - Private

    private func targetPosition(for taskId: UUID, state: CharacterState) -> (Double, Double) {
        switch state {
        case .drinkingCoffee:
            let spot = coffeeAssignments[taskId] ?? nextAvailableCoffeeSpot()
            let pos = PixelOfficeConstants.coffeeBarPositions[spot]
            return (Double(pos.x), Double(pos.y))
        case .working, .needsInput, .idle, .waitingForWork:
            let desk = deskAssignments[taskId] ?? nextAvailableDesk()
            let pos = PixelOfficeConstants.deskPositions[desk]
            return (Double(pos.x), Double(pos.y))
        case .walking:
            if let idx = characters.firstIndex(where: { $0.taskId == taskId }) {
                return (characters[idx].targetX, characters[idx].targetY)
            }
            return (Double(PixelOfficeConstants.officeWidth / 2), Double(PixelOfficeConstants.officeHeight / 2))
        }
    }

    private func nextAvailableDesk() -> Int {
        let usedDesks = Set(deskAssignments.values)
        for i in 0..<PixelOfficeConstants.deskPositions.count {
            if !usedDesks.contains(i) { return i }
        }
        return 0
    }

    private func nextAvailableCoffeeSpot() -> Int {
        let usedSpots = Set(coffeeAssignments.values)
        for i in 0..<PixelOfficeConstants.coffeeBarPositions.count {
            if !usedSpots.contains(i) { return i }
        }
        return 0
    }
}

#else

// Linux fallback
@MainActor
public final class PixelOfficeViewModel {
    public var characters: [PixelCharacter] = []
    private var deskAssignments: [UUID: Int] = [:]
    private var coffeeAssignments: [UUID: Int] = [:]

    public init() {}

    public func updateCharacters(from tasks: [AgentTask]) {
        let relevantTasks = tasks.filter { CharacterState.from(taskStatus: $0.status) != nil }
        let relevantIds = Set(relevantTasks.map { $0.id })
        let existingIds = Set(characters.map { $0.taskId })

        let removedIds = existingIds.subtracting(relevantIds)
        for id in removedIds {
            deskAssignments.removeValue(forKey: id)
            coffeeAssignments.removeValue(forKey: id)
        }
        characters.removeAll { removedIds.contains($0.taskId) }

        for task in relevantTasks {
            guard let targetState = CharacterState.from(taskStatus: task.status) else { continue }

            if let index = characters.firstIndex(where: { $0.taskId == task.id }) {
                let (tx, ty) = targetPosition(for: task.id, state: targetState)
                characters[index].taskName = task.name
                characters[index].targetX = tx
                characters[index].targetY = ty
                if characters[index].isAtTarget {
                    characters[index].state = targetState
                } else {
                    characters[index].state = .walking
                }
                if targetState == .drinkingCoffee {
                    deskAssignments.removeValue(forKey: task.id)
                    if coffeeAssignments[task.id] == nil {
                        coffeeAssignments[task.id] = nextAvailableCoffeeSpot()
                    }
                } else {
                    coffeeAssignments.removeValue(forKey: task.id)
                    if deskAssignments[task.id] == nil {
                        deskAssignments[task.id] = nextAvailableDesk()
                    }
                }
            } else {
                let charIndex = characterIndex(for: task.id)
                if targetState == .drinkingCoffee {
                    coffeeAssignments[task.id] = nextAvailableCoffeeSpot()
                } else {
                    deskAssignments[task.id] = nextAvailableDesk()
                }
                let (px, py) = targetPosition(for: task.id, state: targetState)
                let character = PixelCharacter(
                    taskId: task.id,
                    taskName: task.name,
                    characterIndex: charIndex,
                    positionX: px,
                    positionY: py,
                    state: targetState
                )
                characters.append(character)
            }
        }
    }

    /// Updates characters based on current task list with agent status information
    public func updateCharacters(from tasks: [AgentTask], agentStatuses: [UUID: AgentStatus]) {
        let relevantTasks = tasks.filter { CharacterState.from(taskStatus: $0.status, agentStatus: agentStatuses[$0.id]) != nil }
        let relevantIds = Set(relevantTasks.map { $0.id })
        let existingIds = Set(characters.map { $0.taskId })

        // Remove characters for tasks that are no longer relevant
        let removedIds = existingIds.subtracting(relevantIds)
        for id in removedIds {
            deskAssignments.removeValue(forKey: id)
            coffeeAssignments.removeValue(forKey: id)
        }
        characters.removeAll { removedIds.contains($0.taskId) }

        // Add or update characters
        for task in relevantTasks {
            guard let targetState = CharacterState.from(taskStatus: task.status, agentStatus: agentStatuses[task.id]) else { continue }

            if let index = characters.firstIndex(where: { $0.taskId == task.id }) {
                // Update existing character
                let (tx, ty) = targetPosition(for: task.id, state: targetState)
                characters[index].taskName = task.name
                characters[index].targetX = tx
                characters[index].targetY = ty

                if characters[index].isAtTarget {
                    characters[index].state = targetState
                } else {
                    characters[index].state = .walking
                }

                // Update assignments if state changed
                if targetState == .drinkingCoffee {
                    deskAssignments.removeValue(forKey: task.id)
                    if coffeeAssignments[task.id] == nil {
                        coffeeAssignments[task.id] = nextAvailableCoffeeSpot()
                    }
                } else {
                    coffeeAssignments.removeValue(forKey: task.id)
                    if deskAssignments[task.id] == nil {
                        deskAssignments[task.id] = nextAvailableDesk()
                    }
                }
            } else {
                // Create new character
                let charIndex = characterIndex(for: task.id)

                // Assign position
                if targetState == .drinkingCoffee {
                    coffeeAssignments[task.id] = nextAvailableCoffeeSpot()
                } else {
                    deskAssignments[task.id] = nextAvailableDesk()
                }

                let (px, py) = targetPosition(for: task.id, state: targetState)
                let character = PixelCharacter(
                    taskId: task.id,
                    taskName: task.name,
                    characterIndex: charIndex,
                    positionX: px,
                    positionY: py,
                    state: targetState
                )
                characters.append(character)
            }
        }
    }

    public func moveCharactersTowardTargets() {
        let speed = PixelOfficeConstants.moveSpeed
        for i in characters.indices {
            if !characters[i].isAtTarget {
                let dx = characters[i].targetX - characters[i].positionX
                let dy = characters[i].targetY - characters[i].positionY
                let dist = (dx * dx + dy * dy).squareRoot()
                if dist < speed {
                    characters[i].positionX = characters[i].targetX
                    characters[i].positionY = characters[i].targetY
                } else {
                    characters[i].positionX += (dx / dist) * speed
                    characters[i].positionY += (dy / dist) * speed
                }
                if characters[i].isAtTarget {
                    characters[i].state = .idle
                }
            }
        }
    }

    public func advanceAnimations() {
        for i in characters.indices {
            characters[i].animationFrame = (characters[i].animationFrame + 1) % 4
        }
    }

    public func characterIndex(for taskId: UUID) -> Int {
        let hash = taskId.uuidString.hashValue
        let count = PixelOfficeConstants.characterPalettes.count
        return abs(hash % count)
    }

    private func targetPosition(for taskId: UUID, state: CharacterState) -> (Double, Double) {
        switch state {
        case .drinkingCoffee:
            let spot = coffeeAssignments[taskId] ?? nextAvailableCoffeeSpot()
            let pos = PixelOfficeConstants.coffeeBarPositions[spot]
            return (Double(pos.x), Double(pos.y))
        case .working, .needsInput, .idle, .waitingForWork:
            let desk = deskAssignments[taskId] ?? nextAvailableDesk()
            let pos = PixelOfficeConstants.deskPositions[desk]
            return (Double(pos.x), Double(pos.y))
        case .walking:
            if let idx = characters.firstIndex(where: { $0.taskId == taskId }) {
                return (characters[idx].targetX, characters[idx].targetY)
            }
            return (Double(PixelOfficeConstants.officeWidth / 2), Double(PixelOfficeConstants.officeHeight / 2))
        }
    }

    private func nextAvailableDesk() -> Int {
        let usedDesks = Set(deskAssignments.values)
        for i in 0..<PixelOfficeConstants.deskPositions.count {
            if !usedDesks.contains(i) { return i }
        }
        return 0
    }

    private func nextAvailableCoffeeSpot() -> Int {
        let usedSpots = Set(coffeeAssignments.values)
        for i in 0..<PixelOfficeConstants.coffeeBarPositions.count {
            if !usedSpots.contains(i) { return i }
        }
        return 0
    }
}
#endif
