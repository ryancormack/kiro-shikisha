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
        .frame(minWidth: 500, minHeight: 400, maxHeight: 550)
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No agent profiles configured yet.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        Text("Agent profiles let you save different AI agent setups so you can quickly switch between them when creating tasks. Add one below to get started.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("Agent Configurations")
                    Text("Named profiles that determine which AI agent is used when starting a task.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Toggle("Auto-start agent when workspace is selected", isOn: $settings.autoStartAgent)
            } header: {
                Text("Behavior")
            }
            
            Section {
                Text("Agent configurations are named profiles that determine which AI agent is used when you start a task. Each profile has an identifier that tells the app which agent to run. You can organize profiles with tags and set one as the default for quick access.")
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
    
    @State private var newTag: String = ""
    @State private var isAddingTag: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Default indicator
            if config.isDefault {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text("Default")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            
            // Profile Name
            VStack(alignment: .leading, spacing: 2) {
                Text("Profile Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Enter a name for this profile", text: $config.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
            }
            
            // Agent Identifier
            VStack(alignment: .leading, spacing: 2) {
                Text("Agent Identifier")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g. my-agent-profile", text: $config.agentFlag)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                Text("The identifier used to select which agent profile to run.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Tags
            if !config.tags.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tags")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
            } else if isAddingTag {
                HStack(spacing: 4) {
                    TextField("Tag name", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .frame(maxWidth: 120)
                    Button("Add") {
                        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            config.tags.append(trimmed)
                            newTag = ""
                            isAddingTag = false
                        }
                    }
                    .font(.caption)
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Cancel") {
                        newTag = ""
                        isAddingTag = false
                    }
                    .font(.caption)
                }
            } else {
                Button {
                    isAddingTag = true
                } label: {
                    Label("Add Tags", systemImage: "tag")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
            
            // Action buttons
            Divider()
            
            HStack(spacing: 12) {
                if !config.isDefault {
                    Button {
                        onSetDefault()
                    } label: {
                        Label("Set as Default", systemImage: "star")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 6)
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

            Section {
                Toggle("Show Kiroween Office", isOn: $settings.showKiroweenOffice)
                Text("Display the pixel art House of Kiroween with ghost agents on the dashboard.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Fun Stuff 🎃")
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
