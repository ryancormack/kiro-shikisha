import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Status of an agent task through its lifecycle
public enum TaskStatus: String, Codable, Sendable {
    /// Task has been created but not yet started
    case pending
    /// Task is starting up (agent connecting, workspace preparing)
    case starting
    /// Task is actively being worked on by an agent
    case working
    /// Task needs user attention (approval, error, clarification)
    case needsAttention
    /// Task is paused by the user
    case paused
    /// Task completed successfully
    case completed
    /// Task failed with an error
    case failed
    /// Task was cancelled by the user
    case cancelled

    /// Whether the task is currently active (starting, working, or needs attention)
    public var isActive: Bool {
        switch self {
        case .starting, .working, .needsAttention:
            return true
        default:
            return false
        }
    }

    /// Whether the task has reached a terminal state
    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        default:
            return false
        }
    }

    /// Whether the task needs user attention
    public var needsAttention: Bool {
        self == .needsAttention
    }

    #if canImport(SwiftUI)
    /// Color for UI rendering of this status
    public var displayColor: Color {
        switch self {
        case .pending:
            return .secondary
        case .starting:
            return .blue
        case .working:
            return .green
        case .needsAttention:
            return .orange
        case .paused:
            return .yellow
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .secondary
        }
    }
    #endif

    /// SF Symbol name for this status
    public var iconName: String {
        switch self {
        case .pending:
            return "circle.dashed"
        case .starting:
            return "arrow.trianglehead.clockwise"
        case .working:
            return "gearshape.fill"
        case .needsAttention:
            return "exclamationmark.triangle.fill"
        case .paused:
            return "pause.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .cancelled:
            return "slash.circle.fill"
        }
    }
}
