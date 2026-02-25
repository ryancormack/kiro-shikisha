#if os(macOS)
import SwiftUI
import AppKit

/// Sheet content for creating a new workspace
public struct NewWorkspaceSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDirectory: URL?
    @State private var workspaceName: String = ""
    @State private var startAgentImmediately: Bool = false
    
    /// Callback when workspace is created
    public var onCreate: (Workspace) -> Void
    
    public init(onCreate: @escaping (Workspace) -> Void) {
        self.onCreate = onCreate
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Workspace")
                    .font(.headline)
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Form content
            Form {
                Section {
                    HStack {
                        if let directory = selectedDirectory {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text(directory.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Image(systemName: "folder")
                                .foregroundColor(.secondary)
                            Text("No directory selected")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Choose...") {
                            chooseDirectory()
                        }
                    }
                } header: {
                    Text("Directory")
                }
                
                Section {
                    TextField("Workspace Name", text: $workspaceName)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Name")
                }
                
                Section {
                    Toggle("Start agent immediately", isOn: $startAgentImmediately)
                }
            }
            .formStyle(.grouped)
            .padding()
            
            Divider()
            
            // Footer buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Create Workspace") {
                    createWorkspace()
                }
                .keyboardShortcut(.return)
                .disabled(!canCreate)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 450, height: 320)
    }
    
    private var canCreate: Bool {
        selectedDirectory != nil && !workspaceName.isEmpty
    }
    
    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose Workspace Directory"
        panel.message = "Select a directory to use as your workspace"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let url = panel.url {
            selectedDirectory = url
            // Auto-fill name from directory name if empty
            if workspaceName.isEmpty {
                workspaceName = url.lastPathComponent
            }
        }
    }
    
    private func createWorkspace() {
        guard let directory = selectedDirectory else { return }
        
        let workspace = Workspace(
            name: workspaceName,
            path: directory
        )
        
        onCreate(workspace)
        dismiss()
    }
}

#Preview {
    NewWorkspaceSheet { workspace in
        print("Created workspace: \(workspace.name)")
    }
}
#endif
