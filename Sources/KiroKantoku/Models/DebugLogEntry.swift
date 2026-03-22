import Foundation

/// A raw ACP session update log entry for debugging
public struct DebugLogEntry: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp = Date()
    public let type: String
    public let summary: String
    /// Optional raw JSON payload for detailed inspection
    public let rawJson: String?
    
    public init(type: String, summary: String, rawJson: String? = nil) {
        self.type = type
        self.summary = summary
        self.rawJson = rawJson
    }
}
