#if os(macOS)
import SwiftUI

/// Floating popover showing filtered slash commands for autocomplete.
struct SlashCommandPicker: View {
    let commands: [SlashCommand]
    let filterText: String
    let onSelect: (SlashCommand) -> Void
    let onDismiss: () -> Void

    @Binding var selectedIndex: Int

    private var filteredCommands: [SlashCommand] {
        if filterText.isEmpty {
            return commands
        }
        let query = filterText.lowercased()
        return commands.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        let items = filteredCommands
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, command in
                                commandRow(command, isSelected: index == selectedIndex)
                                    .id(command.id)
                                    .onTapGesture {
                                        onSelect(command)
                                    }
                            }
                        }
                    }
                    .frame(maxHeight: 240)
                    .onChange(of: selectedIndex) { _, newValue in
                        if newValue >= 0 && newValue < items.count {
                            proxy.scrollTo(items[newValue].id, anchor: .center)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(DesignConstants.popoverShadowOpacity), radius: DesignConstants.popoverShadowRadius, y: -2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium)
                    .stroke(DesignConstants.separatorColor, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium))
            .onKeyPress(.upArrow) {
                if selectedIndex > 0 {
                    selectedIndex -= 1
                }
                return .handled
            }
            .onKeyPress(.downArrow) {
                if selectedIndex < items.count - 1 {
                    selectedIndex += 1
                }
                return .handled
            }
            .onKeyPress(.return) {
                if selectedIndex >= 0 && selectedIndex < items.count {
                    onSelect(items[selectedIndex])
                }
                return .handled
            }
            .onKeyPress(.escape) {
                onDismiss()
                return .handled
            }
            .onChange(of: filterText) { _, _ in
                selectedIndex = 0
            }
        }
    }

    @ViewBuilder
    private func commandRow(_ command: SlashCommand, isSelected: Bool) -> some View {
        HStack(spacing: DesignConstants.spacingSM) {
            Text("/\(command.name)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)

            if command.isSkill {
                Text("Skill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: DesignConstants.badgeCornerRadius))
                    .accessibilityLabel("Skill-based slash command")
            }

            Text(command.description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.horizontal, DesignConstants.spacingMD)
        .padding(.vertical, DesignConstants.spacingSM)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }
}
#endif
