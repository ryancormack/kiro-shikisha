import Foundation

/// A raw ACP session update log entry for debugging
public struct DebugLogEntry: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp = Date()
    public let type: String
    public let summary: String
}
