#if os(macOS)
import Foundation
import ACPModel

/// The type of input a slash command expects
public enum SlashCommandInputType: Sendable {
    /// Command requires selecting from a list of options (e.g. /model)
    case selection
    /// Command opens a panel and displays a response message (e.g. /context)
    case panel
    /// Simple fire-and-execute command (e.g. /clear)
    case simple
    /// Client-side command handled locally (e.g. /quit)
    case local
}

/// Unified slash command model that merges standard ACP commands and Kiro extension commands
/// into a single display model for the autocomplete picker.
public struct SlashCommand: Identifiable, Sendable {
    public var id: String { name }
    /// Command name without the leading /
    public let name: String
    /// Human-readable description
    public let description: String
    /// What kind of input this command expects
    public let inputType: SlashCommandInputType
    /// Method name for fetching options (only for .selection type)
    public let optionsMethod: String?
    /// Hint text for the input field
    public let hint: String?

    public init(name: String, description: String, inputType: SlashCommandInputType = .simple, optionsMethod: String? = nil, hint: String? = nil) {
        self.name = name
        self.description = description
        self.inputType = inputType
        self.optionsMethod = optionsMethod
        self.hint = hint
    }
}

/// Builds a merged list of SlashCommand from standard ACP commands and Kiro extension commands.
public func mergeSlashCommands(
    acpCommands: [AvailableCommand],
    kiroCommands: [KiroAvailableCommand]
) -> [SlashCommand] {
    var result: [SlashCommand] = []
    var seen = Set<String>()

    // Kiro commands have richer metadata, so process them first
    for cmd in kiroCommands {
        guard !seen.contains(cmd.name) else { continue }
        seen.insert(cmd.name)

        var inputType: SlashCommandInputType = .simple
        var optionsMethod: String?

        if let meta = cmd.meta?.objectValue {
            if meta["local"]?.boolValue == true {
                inputType = .local
            } else if let it = meta["inputType"]?.stringValue {
                switch it {
                case "selection":
                    inputType = .selection
                    optionsMethod = meta["optionsMethod"]?.stringValue
                case "panel":
                    inputType = .panel
                default:
                    inputType = .simple
                }
            }
        }

        result.append(SlashCommand(
            name: cmd.name,
            description: cmd.description,
            inputType: inputType,
            optionsMethod: optionsMethod
        ))
    }

    // Add standard ACP commands that weren't already added from Kiro
    for cmd in acpCommands {
        guard !seen.contains(cmd.name) else { continue }
        seen.insert(cmd.name)

        var hint: String?
        if case .unstructured(let ui) = cmd.input {
            hint = ui.hint
        }

        result.append(SlashCommand(
            name: cmd.name,
            description: cmd.description,
            inputType: .simple,
            hint: hint
        ))
    }

    return result.sorted { $0.name < $1.name }
}
#endif
