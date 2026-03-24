#if os(macOS)
import SwiftUI

/// Compact, collapsible panel showing available skills above the chat input
struct SkillsPanel: View {
    let skills: [Skill]
    let onUseSkill: (String) -> Void

    @State private var isExpanded = false

    var body: some View {
        if !skills.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: DesignConstants.spacingXS) {
                    ForEach(skills) { skill in
                        HStack(spacing: DesignConstants.spacingSM) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: DesignConstants.spacingXS) {
                                    Text(skill.name)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    if skill.isActive {
                                        Text("Active")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.green)
                                            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.badgeCornerRadius))
                                    }
                                }
                                Text(skill.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button("Use") {
                                onUseSkill(skill.name)
                            }
                            .font(.caption)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } label: {
                Text("Skills (\(skills.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, DesignConstants.spacingMD)
            .padding(.vertical, DesignConstants.spacingXS)
        }
    }
}
#endif
