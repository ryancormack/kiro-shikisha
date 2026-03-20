#if os(macOS)
import SwiftUI
import ACPModel

/// Compact selector bar for session configuration options (model, agent, etc.)
/// Displayed above the chat input when config options are available from the server.
struct ConfigSelectorBar: View {
    let agent: Agent
    let onError: (String) -> Void
    @Environment(AgentManager.self) private var agentManager

    var body: some View {
        if !agent.configOptions.isEmpty {
            HStack(spacing: DesignConstants.spacingSM) {
                ForEach(selectOptions, id: \.id.value) { option in
                    ConfigOptionPicker(
                        option: option,
                        onChange: { newValue in
                            changeConfigOption(configId: option.id.value, value: newValue)
                        }
                    )
                }
                Spacer()
            }
            .padding(.horizontal, DesignConstants.spacingMD)
            .padding(.vertical, DesignConstants.spacingXS)
        }
    }

    /// Extract all select options from agent.configOptions
    private var selectOptions: [SessionConfigOptionSelect] {
        agent.configOptions.compactMap { option in
            if case .select(let selectOption) = option {
                return selectOption
            }
            return nil
        }
    }

    private func changeConfigOption(configId: String, value: String) {
        Task {
            do {
                try await agentManager.setConfigOption(agentId: agent.id, configId: configId, value: value)
            } catch {
                onError(error.localizedDescription)
            }
        }
    }
}

/// A single config option picker rendered as a compact Menu dropdown.
struct ConfigOptionPicker: View {
    let option: SessionConfigOptionSelect
    let onChange: (String) -> Void

    @State private var selectedValue: String

    init(option: SessionConfigOptionSelect, onChange: @escaping (String) -> Void) {
        self.option = option
        self.onChange = onChange
        self._selectedValue = State(initialValue: option.currentValue.value)
    }

    var body: some View {
        Menu {
            switch option.options {
            case .flat(let options):
                ForEach(options, id: \.value.value) { item in
                    Button {
                        selectedValue = item.value.value
                        onChange(item.value.value)
                    } label: {
                        if item.value.value == selectedValue {
                            Label(item.name, systemImage: "checkmark")
                        } else {
                            Text(item.name)
                        }
                    }
                }
            case .grouped(let groups):
                ForEach(groups, id: \.group.value) { group in
                    Section(group.name) {
                        ForEach(group.options, id: \.value.value) { item in
                            Button {
                                selectedValue = item.value.value
                                onChange(item.value.value)
                            } label: {
                                if item.value.value == selectedValue {
                                    Label(item.name, systemImage: "checkmark")
                                } else {
                                    Text(item.name)
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignConstants.spacingXS) {
                Text(option.name)
                    .foregroundColor(.secondary)
                Text(currentValueName)
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
            .padding(.horizontal, DesignConstants.spacingSM)
            .padding(.vertical, DesignConstants.spacingXS)
            .background(DesignConstants.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusSmall))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .controlSize(.small)
        .onChange(of: option.currentValue.value) { _, newValue in
            selectedValue = newValue
        }
    }

    /// Resolve the display name for the currently selected value.
    private var currentValueName: String {
        let allOptions: [SessionConfigSelectOption]
        switch option.options {
        case .flat(let options):
            allOptions = options
        case .grouped(let groups):
            allOptions = groups.flatMap { $0.options }
        }
        return allOptions.first(where: { $0.value.value == selectedValue })?.name ?? selectedValue
    }
}
#endif
