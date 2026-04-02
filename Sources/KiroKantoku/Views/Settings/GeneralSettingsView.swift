#if os(macOS)
import SwiftUI

/// Settings view for general application configuration
public struct GeneralSettingsView: View {
    @Environment(AppSettings.self) private var settings
    
    @State private var showFolderPicker: Bool = false
    @State private var isPathValid: Bool = true
    @State private var isDirectoryValid: Bool = true
    
    public init() {}
    
    public var body: some View {
        @Bindable var settings = settings
        
        Form {
            Section {
                HStack {
                    TextField("kiro-cli Path", text: $settings.kirocliPath)
                        .textFieldStyle(.roundedBorder)
                    
                    // Validation indicator
                    Image(systemName: isPathValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isPathValid ? .green : .red)
                        .help(isPathValid ? "kiro-cli found" : "kiro-cli not found or not executable")
                    
                    Button("Browse...") {
                        browseForKiroCli()
                    }
                }
                .onChange(of: settings.kirocliPath) { _, _ in
                    validatePath()
                }
                
                Text("Path to the kiro-cli executable. Use ~ for home directory.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("kiro-cli Location")
            }
            
            Section {
                HStack {
                    TextField("Default Workspace Directory", text: $settings.defaultWorkspaceDirectory)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                    
                    // Validation indicator
                    Image(systemName: isDirectoryValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isDirectoryValid ? .green : .red)
                        .help(isDirectoryValid ? "Directory exists" : "Directory not found")
                    
                    Button("Browse...") {
                        showFolderPicker = true
                    }
                }
                .onChange(of: settings.defaultWorkspaceDirectory) { _, _ in
                    validateDirectory()
                }
                
                Text("Default directory when creating new workspaces.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Workspace")
            }
            
            Section {
                Toggle("Launch at Login", isOn: $settings.launchAtStartup)
                    .help("Automatically start Kiro Kantoku when you log in")
            } header: {
                Text("Startup")
            }
            
            Section {
                Toggle("Enter to Send", isOn: $settings.enterToSend)
                    .help("Press Enter to send messages. Use Shift+Enter for new lines.")
                
                Text("When enabled, pressing Enter sends the message. Use Shift+Enter to insert a new line.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Chat Input")
            }
        }
        .formStyle(.grouped)
        .padding()
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                settings.defaultWorkspaceDirectory = url.path
                validateDirectory()
            }
        }
        .onAppear {
            validatePath()
            validateDirectory()
        }
    }
    
    // MARK: - Private Methods
    
    private func validatePath() {
        isPathValid = settings.validateKirocliPath()
    }
    
    private func validateDirectory() {
        isDirectoryValid = settings.validateDefaultWorkspaceDirectory()
    }
    
    private func browseForKiroCli() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")
        panel.message = "Select the kiro-cli executable"
        panel.prompt = "Select"
        
        if panel.runModal() == .OK, let url = panel.url {
            settings.kirocliPath = url.path
            validatePath()
        }
    }
}

#Preview {
    GeneralSettingsView()
        .environment(AppSettings())
}
#endif
