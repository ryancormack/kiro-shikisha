#if os(macOS)
import SwiftUI
import ACPModel

/// Compact selector bar for session mode and model, displayed above the chat input.
struct ConfigSelectorBar: View {
    let agent: Agent
    let onError: (String) -> Void
    @Environment(AgentManager.self) private var agentManager

    var body: some View {
        let hasModes = agent.availableModes.count > 1
        let hasModels = !agent.availableModels.isEmpty

        if hasModes || hasModels {
            HStack(spacing: DesignConstants.spacingSM) {
                if hasModes {
                    ModePicker(
                        modes: agent.availableModes,
                        currentModeId: agent.currentModeId,
                        onChange: { modeId in
                            Task {
                                do {
                                    try await agentManager.setMode(agentId: agent.id, modeId: modeId)
                                } catch { onError(error.localizedDescription) }
                            }
                        }
                    )
                }
                if hasModels {
                    ModelPicker(
                        models: agent.availableModels,
                        currentModelId: agent.currentModelId,
                        onChange: { modelId in
                            Task {
                                do {
                                    try await agentManager.setModel(agentId: agent.id, modelId: modelId)
                                } catch { onError(error.localizedDescription) }
                            }
                        }
                    )
                }
                Spacer()
            }
            .padding(.horizontal, DesignConstants.spacingMD)
            .padding(.vertical, DesignConstants.spacingXS)
        }
    }
}

// MARK: - Pickers

private struct ModePicker: View {
    let modes: [SessionMode]
    let currentModeId: SessionModeId?
    let onChange: (String) -> Void

    var body: some View {
        Menu {
            ForEach(modes, id: \.id.value) { mode in
                Button {
                    onChange(mode.id.value)
                } label: {
                    if mode.id.value == currentModeId?.value {
                        Label(mode.name, systemImage: "checkmark")
                    } else {
                        Text(mode.name)
                    }
                }
            }
        } label: {
            pickerLabel(
                title: "Agent",
                value: modes.first(where: { $0.id.value == currentModeId?.value })?.name ?? "—"
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .controlSize(.small)
    }
}

private struct ModelPicker: View {
    let models: [ModelInfo]
    let currentModelId: ModelId?
    let onChange: (String) -> Void

    var body: some View {
        Menu {
            ForEach(models, id: \.modelId.value) { model in
                Button {
                    onChange(model.modelId.value)
                } label: {
                    if model.modelId.value == currentModelId?.value {
                        Label(model.name, systemImage: "checkmark")
                    } else {
                        Text(model.name)
                    }
                }
            }
        } label: {
            pickerLabel(
                title: "Model",
                value: models.first(where: { $0.modelId.value == currentModelId?.value })?.name ?? "—"
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .controlSize(.small)
    }
}

// MARK: - Shared label

private func pickerLabel(title: String, value: String) -> some View {
    HStack(spacing: DesignConstants.spacingXS) {
        Text(title)
            .foregroundColor(.secondary)
        Text(value)
        Image(systemName: "chevron.up.chevron.down")
            .foregroundColor(.secondary)
    }
    .font(.caption)
    .padding(.horizontal, DesignConstants.spacingSM)
    .padding(.vertical, DesignConstants.spacingXS)
    .background(DesignConstants.controlBackground)
    .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusSmall))
}
#endif
