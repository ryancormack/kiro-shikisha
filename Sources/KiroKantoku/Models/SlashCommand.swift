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
    /// True when this command comes from a skill (`.kiro/skills/` or `~/.kiro/skills/`)
    /// as opposed to a built-in kiro-cli command.
    public let isSkill: Bool

    public init(
        name: String,
        description: String,
        inputType: SlashCommandInputType = .simple,
        optionsMethod: String? = nil,
        hint: String? = nil,
        isSkill: Bool = false
    ) {
        self.name = name
        self.description = description
        self.inputType = inputType
        self.optionsMethod = optionsMethod
        self.hint = hint
        self.isSkill = isSkill
    }
}

/// Commands that either don't make sense in a GUI (they drop into a terminal editor,
/// pager, etc.) or duplicate functionality the app already provides via its own UI.
/// Everything the server advertises that is NOT in this set passes through.
///
/// Notes on each entry:
/// - editor/reply: open `$EDITOR` for long-form input — nonsensical inside a Mac app.
/// - transcript/pager: open `$PAGER` like `less`.
/// - logdump: writes a zip to CWD from the CLI process; not useful from the GUI.
/// - theme: terminal color overrides.
/// - experiment: toggles experimental CLI features.
/// - paste: we handle clipboard images natively with ⌘V.
/// - todos/issue/tangent: CLI-only UX flows we don't wire into the GUI.
/// - quit: the GUI has its own quit mechanism; let the user close the window instead.
private let guiIncompatibleCommands: Set<String> = [
    "editor", "reply", "transcript", "logdump", "theme",
    "experiment", "paste", "todos", "issue", "tangent", "quit", "exit", "q"
]

/// Builds a merged list of SlashCommand from standard ACP commands, Kiro extension commands,
/// and skill-based slash commands discovered on disk. The result is ordered so built-in
/// commands appear first (alphabetically) and skill-based commands appear after them
/// (also alphabetically), which matches how users typically think about the `/` menu.
public func mergeSlashCommands(
    acpCommands: [AvailableCommand],
    kiroCommands: [KiroAvailableCommand],
    skills: [Skill] = []
) -> [SlashCommand] {
    var result: [SlashCommand] = []
    var seen = Set<String>()

    // Kiro commands have richer metadata, so process them first
    for cmd in kiroCommands {
        // Strip leading "/" from command name - Kiro sends names like "/agent"
        let name = cmd.name.hasPrefix("/") ? String(cmd.name.dropFirst()) : cmd.name
        guard !seen.contains(name) else { continue }
        seen.insert(name)

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
            name: name,
            description: cmd.description,
            inputType: inputType,
            optionsMethod: optionsMethod
        ))
    }

    // Add standard ACP commands that weren't already added from Kiro
    for cmd in acpCommands {
        // Strip leading "/" from command name
        let name = cmd.name.hasPrefix("/") ? String(cmd.name.dropFirst()) : cmd.name
        guard !seen.contains(name) else { continue }
        seen.insert(name)

        var hint: String?
        if case .unstructured(let ui) = cmd.input {
            hint = ui.hint
        }

        result.append(SlashCommand(
            name: name,
            description: cmd.description,
            inputType: .simple,
            hint: hint
        ))
    }

    // Drop GUI-incompatible commands before we consider skills so a skill named,
    // say, "paste" (unusual, but legal) can still appear.
    result.removeAll { guiIncompatibleCommands.contains($0.name) }

    // Sort the built-in commands alphabetically before appending skills.
    result.sort { $0.name < $1.name }

    // Append skill-based commands — each discovered skill is a valid slash command.
    // Skip any whose name collides with a server-advertised command we already have.
    let skillCommands = skills
        .filter { !seen.contains($0.name) }
        .sorted { $0.name < $1.name }
        .map { skill in
            SlashCommand(
                name: skill.name,
                description: skill.description,
                inputType: .simple,
                isSkill: true
            )
        }
    result.append(contentsOf: skillCommands)

    return result
}
#endif
