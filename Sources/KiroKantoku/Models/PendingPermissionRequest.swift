import Foundation
import ACPModel

/// Display model for a pending permission request shown in the UI
public struct PermissionOptionDisplay: Identifiable, Sendable {
    public var id: String { optionId }
    /// The option ID to send back in the response
    public let optionId: String
    /// Human-readable label for the button
    public let label: String
    /// The kind of permission (for styling)
    public let kind: String  // "allow_once", "allow_always", "reject_once", "reject_always"
    
    public init(optionId: String, label: String, kind: String) {
        self.optionId = optionId
        self.label = label
        self.kind = kind
    }
}

/// A pending permission request that needs user interaction
public struct PendingPermissionRequest: Identifiable, Sendable {
    public let id: UUID
    /// Title of the tool call (e.g., "shell")
    public let toolCallTitle: String
    /// Kind of tool call (e.g., "execute")
    public let toolCallKind: String?
    /// The raw input to display (e.g., the shell command)
    public let rawInput: String?
    /// Available options for the user to choose from
    public let options: [PermissionOptionDisplay]
    
    public init(
        id: UUID = UUID(),
        toolCallTitle: String,
        toolCallKind: String? = nil,
        rawInput: String? = nil,
        options: [PermissionOptionDisplay]
    ) {
        self.id = id
        self.toolCallTitle = toolCallTitle
        self.toolCallKind = toolCallKind
        self.rawInput = rawInput
        self.options = options
    }
}
