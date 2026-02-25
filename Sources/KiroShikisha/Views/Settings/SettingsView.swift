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
        .frame(width: 500, height: 350)
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
                TextField("Default Agent Config", text: $settings.defaultAgentConfig)
                    .textFieldStyle(.roundedBorder)
                    .help("Path to agent configuration file (passed via --agent flag)")
                
                Toggle("Auto-start agent when workspace is selected", isOn: $settings.autoStartAgent)
            } header: {
                Text("Agent Configuration")
            }
            
            Section {
                Text("Agent configurations define the model, tools, and behavior for the AI agent. Leave empty to use the default kiro-cli configuration.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Help")
            }
        }
        .formStyle(.grouped)
        .padding()
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
