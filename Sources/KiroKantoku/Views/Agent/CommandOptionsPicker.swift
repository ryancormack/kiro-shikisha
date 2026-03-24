#if os(macOS)
import SwiftUI

/// Secondary picker for displaying command options grouped by their group field.
struct CommandOptionsPicker: View {
    let options: [CommandOption]
    let filterText: String
    let onSelect: (CommandOption) -> Void
    let onDismiss: () -> Void

    @Binding var selectedIndex: Int

    private var filteredOptions: [CommandOption] {
        if filterText.isEmpty {
            return options
        }
        let query = filterText.lowercased()
        return options.filter {
            $0.label.lowercased().contains(query) ||
            ($0.description?.lowercased().contains(query) ?? false)
        }
    }

    /// Groups the filtered options by their group field, preserving order.
    private var groupedOptions: [(group: String?, options: [CommandOption])] {
        let items = filteredOptions
        var groups: [(group: String?, options: [CommandOption])] = []
        var currentGroup: String? = nil
        var currentItems: [CommandOption] = []

        for option in items {
            if option.group != currentGroup {
                if !currentItems.isEmpty {
                    groups.append((group: currentGroup, options: currentItems))
                }
                currentGroup = option.group
                currentItems = [option]
            } else {
                currentItems.append(option)
            }
        }
        if !currentItems.isEmpty {
            groups.append((group: currentGroup, options: currentItems))
        }
        return groups
    }

    /// Flat list of all filtered options for index-based keyboard navigation.
    private var flatFiltered: [CommandOption] {
        filteredOptions
    }

    var body: some View {
        let items = flatFiltered
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            let grouped = groupedOptions
                            ForEach(Array(grouped.enumerated()), id: \.offset) { _, section in
                                if let group = section.group {
                                    Text(group)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, DesignConstants.spacingMD)
                                        .padding(.top, DesignConstants.spacingSM)
                                        .padding(.bottom, DesignConstants.spacingXS)
                                }
                                ForEach(section.options) { option in
                                    let flatIndex = items.firstIndex(where: { $0.id == option.id }) ?? 0
                                    optionRow(option, isSelected: flatIndex == selectedIndex)
                                        .id(option.id)
                                        .onTapGesture {
                                            onSelect(option)
                                        }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 280)
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
    private func optionRow(_ option: CommandOption, isSelected: Bool) -> some View {
        HStack(spacing: DesignConstants.spacingSM) {
            Text(option.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)

            if let desc = option.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()
        }
        .padding(.horizontal, DesignConstants.spacingMD)
        .padding(.vertical, DesignConstants.spacingSM)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }
}
#endif
