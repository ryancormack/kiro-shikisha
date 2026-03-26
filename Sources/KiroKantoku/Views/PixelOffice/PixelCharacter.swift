import Foundation

/// Visual state of a pixel character in the office
public enum CharacterState: String, Sendable {
    /// Character is at their desk working (typing animation)
    case working
    /// Character is at the coffee bar (holding cup)
    case drinkingCoffee
    /// Character needs human input (speech bubble with !)
    case needsInput
    /// Character is walking between positions
    case walking
    /// Character is standing idle
    case idle

    /// Maps a TaskStatus to a CharacterState, or nil if the task should not be shown
    public static func from(taskStatus: TaskStatus) -> CharacterState? {
        switch taskStatus {
        case .working, .starting:
            return .working
        case .paused:
            return .drinkingCoffee
        case .needsAttention:
            return .needsInput
        case .pending:
            return .idle
        case .completed, .failed, .cancelled:
            return nil
        }
    }
}

/// A pixel character representing a task in the virtual office
public struct PixelCharacter: Identifiable, Sendable {
    public let id: UUID  // same as taskId
    public let taskId: UUID
    public var taskName: String
    public var characterIndex: Int
    public var positionX: Double
    public var positionY: Double
    public var targetX: Double
    public var targetY: Double
    public var state: CharacterState
    public var animationFrame: Int

    public init(
        taskId: UUID,
        taskName: String,
        characterIndex: Int,
        positionX: Double,
        positionY: Double,
        state: CharacterState = .idle,
        animationFrame: Int = 0
    ) {
        self.id = taskId
        self.taskId = taskId
        self.taskName = taskName
        self.characterIndex = characterIndex
        self.positionX = positionX
        self.positionY = positionY
        self.targetX = positionX
        self.targetY = positionY
        self.state = state
        self.animationFrame = animationFrame
    }

    /// Whether the character is close enough to its target to stop walking
    public var isAtTarget: Bool {
        abs(positionX - targetX) < 0.1 && abs(positionY - targetY) < 0.1
    }
}
