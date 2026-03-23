#if os(macOS)
import SwiftUI
import ACPModel

/// Compact selector bar for session agent and model, displayed above the chat input.
struct ConfigSelectorBar: View {
    let agent: Agent
    let onError: (String) -> Void
    @Environment(AgentManager.self) private var agentManager
    @State private var selectedModeId: String = ""
    @State private var selectedModelId: String = ""

    var body: some View {
        let hasModes = agent.availableModes.count > 1
        let hasModels = !agent.availableModels.isEmpty

        if hasModes || hasModels {
            VStack(spacing: 0) {
            Divider()
            HStack(spacing: DesignConstants.spacingSM) {
                if hasModes {
                    Picker("Agent", selection: $selectedModeId) {
                        ForEach(agent.availableModes, id: \.id.value) { mode in
                            Text(mode.name).tag(mode.id.value)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .fixedSize()
                    .onChange(of: selectedModeId) { _, newValue in
                        guard !newValue.isEmpty, newValue != agent.currentModeId?.value else { return }
                        Task {
                            do {
                                try await agentManager.setMode(agentId: agent.id, modeId: newValue)
                            } catch { onError(error.localizedDescription) }
                        }
                    }
                }
                if hasModels {
                    Picker("Model", selection: $selectedModelId) {
                        ForEach(agent.availableModels, id: \.modelId.value) { model in
                            Text(model.name).tag(model.modelId.value)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .fixedSize()
                    .onChange(of: selectedModelId) { _, newValue in
                        guard !newValue.isEmpty, newValue != agent.currentModelId?.value else { return }
                        Task {
                            do {
                                try await agentManager.setModel(agentId: agent.id, modelId: newValue)
                            } catch { onError(error.localizedDescription) }
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, DesignConstants.spacingMD)
            .padding(.vertical, DesignConstants.spacingXS)
            .onAppear {
                selectedModeId = agent.currentModeId?.value ?? ""
                selectedModelId = agent.currentModelId?.value ?? ""
            }
            .onChange(of: agent.currentModeId?.value) { _, newValue in
                if let newValue, newValue != selectedModeId {
                    selectedModeId = newValue
                }
            }
            .onChange(of: agent.currentModelId?.value) { _, newValue in
                if let newValue, newValue != selectedModelId {
                    selectedModelId = newValue
                }
            }
            } // end VStack
        }
    }
}
#endif
