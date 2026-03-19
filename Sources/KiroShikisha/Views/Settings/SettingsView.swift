#if os(macOS)
import SwiftUI

/// Main settings view with tabs for different setting categories
public struct SettingsView: View {
    public init() {}
    
    public var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            AgentSettingsView()
                .tabItem {
                    Label("Agents", systemImage: "person.crop.circle")
                }
            
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
        }
        .frame(minHeight: 350, maxHeight: 500)
        .padding()
    }
}

/// Settings view for agent configuration
public struct AgentSettingsView: View {
    @Environment(AppSettings.self) private var settings
    
    public init() {}
    
    public var body: some View {
        @Bindable var settings = settings
        
        Form {
            Section {
                if settings.agentConfigurations.isEmpty {
                    Text("No agent configurations. Add one to get started.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(settings.agentConfigurations.indices, id: \.self) { index in
                        AgentConfigRow(
                            config: $settings.agentConfigurations[index],
                            onSetDefault: { setDefault(index: index) },
                            onDelete: { deleteConfig(index: index) }
                        )
                    }
                }
                
                Button {
                    addConfiguration()
                } label: {
                    Label("Add Configuration", systemImage: "plus")
                }
            } header: {
                Text("Agent Configurations")
            }
            
            Section {
                Toggle("Auto-start agent when workspace is selected", isOn: $settings.autoStartAgent)
            } header: {
                Text("Behavior")
            }
            
            Section {
                Text("Agent configurations define which kiro-cli agent profile to use. The agent flag value is passed via the --agent flag. Tags help categorize configurations.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Help")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func addConfiguration() {
        let config = AgentConfiguration(
            name: "New Configuration",
            agentFlag: "",
            tags: [],
            isDefault: settings.agentConfigurations.isEmpty
        )
        settings.agentConfigurations.append(config)
    }
    
    private func setDefault(index: Int) {
        for i in settings.agentConfigurations.indices {
            settings.agentConfigurations[i].isDefault = (i == index)
        }
    }
    
    private func deleteConfig(index: Int) {
        let wasDefault = settings.agentConfigurations[index].isDefault
        settings.agentConfigurations.remove(at: index)
        if wasDefault, let first = settings.agentConfigurations.indices.first {
            settings.agentConfigurations[first].isDefault = true
        }
    }
}

struct AgentConfigRow: View {
    @Binding var config: AgentConfiguration
    let onSetDefault: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if config.isDefault {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
                TextField("Name", text: $config.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
            }
            
            HStack {
                Text("--agent")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Agent flag", text: $config.agentFlag)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }
            
            if !config.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(config.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
            
            HStack(spacing: 12) {
                if !config.isDefault {
                    Button("Set as Default") { onSetDefault() }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                }
                Button("Delete") { onDelete() }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Settings view for appearance customization
public struct AppearanceSettingsView: View {
    @Environment(AppSettings.self) private var settings
    
    public init() {}
    
    public var body: some View {
        @Bindable var settings = settings
        
        Form {
            Section {
                Picker("Theme", selection: $settings.theme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Theme")
            }
            
            Section {
                HStack {
                    Text("Font Size")
                    Spacer()
                    Text("\(Int(settings.fontSize)) pt")
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.fontSize, in: 10...20, step: 1)
            } header: {
                Text("Typography")
            }
            
            Section {
                Picker("Code Panel Position", selection: $settings.codePanelPosition) {
                    Text("Right").tag("right")
                    Text("Bottom").tag("bottom")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Layout")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview("Settings") {
    SettingsView()
        .environment(AppSettings())
}

#Preview("Agent Settings") {
    AgentSettingsView()
        .environment(AppSettings())
}

#Preview("Appearance Settings") {
    AppearanceSettingsView()
        .environment(AppSettings())
}
#endif
