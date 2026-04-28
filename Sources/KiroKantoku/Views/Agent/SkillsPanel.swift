#if os(macOS)
import SwiftUI

/// Compact, collapsible panel showing available skills above the chat input.
///
/// Each skill can be invoked either as a real `/skill-name` slash command
/// (if the server advertises it or we know kiro-cli supports skill-based slash
/// commands) or, as a fallback, by sending a natural-language prompt that asks
/// the agent to use the skill.
struct SkillsPanel: View {
    let skills: [Skill]
    /// The set of slash-command names the agent has advertised, used to
    /// decide whether a skill can be invoked as a real slash command.
    let availableCommandNames: Set<String>
    /// Fires when the user taps the "Use" button. The second argument indicates
    /// whether the caller should invoke `/skill.name` as a slash command (true)
    /// or send a natural-language prompt (false).
    let onUseSkill: (Skill, Bool) -> Void
    /// Optional: re-scan the workspace for skills.
    let onRefresh: (() -> Void)?

    @State private var isExpanded = false

    init(
        skills: [Skill],
        availableCommandNames: Set<String> = [],
        onRefresh: (() -> Void)? = nil,
        onUseSkill: @escaping (Skill, Bool) -> Void
    ) {
        self.skills = skills
        self.availableCommandNames = availableCommandNames
        self.onRefresh = onRefresh
        self.onUseSkill = onUseSkill
    }

    var body: some View {
        // Show the panel even when there are no skills so the refresh button
        // stays reachable — users installing a new skill want to pick it up
        // without restarting the task.
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DesignConstants.spacingXS) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Text(skills.isEmpty ? "Skills" : "Skills (\(skills.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let onRefresh = onRefresh {
                        Button {
                            onRefresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Re-scan .kiro/skills/ and ~/.kiro/skills/")
                    }
                }
                .contentShape(Rectangle())
                .padding(.horizontal, DesignConstants.spacingMD)
                .padding(.vertical, DesignConstants.spacingSM)
            }
            .buttonStyle(.plain)

            if isExpanded {
                if skills.isEmpty {
                    Text("No skills found in .kiro/skills/ or ~/.kiro/skills/. Create a folder with a SKILL.md inside to add one.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, DesignConstants.spacingMD)
                        .padding(.bottom, DesignConstants.spacingSM)
                } else {
                    VStack(alignment: .leading, spacing: DesignConstants.spacingXS) {
                        ForEach(skills) { skill in
                            skillRow(skill)
                        }
                    }
                    .padding(.horizontal, DesignConstants.spacingMD)
                    .padding(.bottom, DesignConstants.spacingSM)
                }
            }
        }
    }

    @ViewBuilder
    private func skillRow(_ skill: Skill) -> some View {
        HStack(spacing: DesignConstants.spacingSM) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignConstants.spacingXS) {
                    Text("/\(skill.name)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    if skill.isActive {
                        Text("Active")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.badgeCornerRadius))
                    }
                    if !skill.references.isEmpty {
                        Text("\(skill.references.count) ref\(skill.references.count == 1 ? "" : "s")")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.badgeCornerRadius))
                    }
                }
                Text(skill.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Use") {
                // Prefer invoking as a slash command when the server advertises
                // it (kiro-cli ≥ skill-based slash commands). Otherwise fall back
                // to a natural-language prompt for older CLIs.
                let asSlashCommand = availableCommandNames.contains(skill.name)
                onUseSkill(skill, asSlashCommand)
            }
            .font(.caption)
            .controlSize(.small)
            .help(availableCommandNames.contains(skill.name)
                  ? "Invoke as /\(skill.name)"
                  : "Send a prompt asking the agent to use this skill")
        }
        .padding(.vertical, 2)
    }
}
#endif
