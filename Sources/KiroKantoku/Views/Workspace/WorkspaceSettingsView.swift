#if os(macOS)
import SwiftUI

/// View for editing workspace settings
public struct WorkspaceSettingsView: View {
    /// The workspace being edited
    @Binding var workspace: Workspace
    /// Git repository info (if workspace is in a git repo)
    let repository: GitRepository?
    /// List of worktrees (if git repo)
    let worktrees: [GitWorktree]
    /// Callback when delete is requested
    var onDelete: (() -> Void)?
    
    @State private var editedName: String = ""
    @State private var showDeleteConfirmation: Bool = false
    
    public init(
        workspace: Binding<Workspace>,
        repository: GitRepository? = nil,
        worktrees: [GitWorktree] = [],
        onDelete: (() -> Void)? = nil
    ) {
        self._workspace = workspace
        self.repository = repository
        self.worktrees = worktrees
        self.onDelete = onDelete
    }
    
    public var body: some View {
        Form {
            Section("General") {
                generalSettings
            }
            
            Section("Path") {
                pathInfo
            }
            
            if repository != nil {
                Section("Git Information") {
                    gitInfo
                }
                
                if !worktrees.isEmpty {
                    Section("Worktrees") {
                        worktreesList
                    }
                }
            }
            
            Section {
                deleteButton
            }
        }
        .formStyle(.grouped)
        .onAppear {
            editedName = workspace.name
        }
        .onChange(of: editedName) { _, newValue in
            workspace.name = newValue
        }
        .alert("Delete Workspace?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("This will remove the workspace from the app. The files on disk will not be affected.")
        }
    }
    
    @ViewBuilder
    private var generalSettings: some View {
        HStack {
            Text("Name")
            Spacer()
            TextField("Workspace Name", text: $editedName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
        }
        
        if workspace.sourceWorkspaceId != nil {
            HStack {
                Text("Type")
                Spacer()
                Label("Worktree", systemImage: "arrow.triangle.branch")
                    .foregroundColor(.purple)
            }
        }
    }
    
    @ViewBuilder
    private var pathInfo: some View {
        HStack {
            Text("Location")
            Spacer()
            Text(workspace.path.path)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        
        HStack {
            Text("Created")
            Spacer()
            Text(workspace.createdAt, style: .date)
                .foregroundColor(.secondary)
        }
        
        HStack {
            Text("Last Accessed")
            Spacer()
            Text(workspace.lastAccessedAt, style: .relative)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var gitInfo: some View {
        if let repo = repository {
            HStack {
                Text("Branch")
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(.purple)
                    Text(repo.currentBranch ?? "Detached HEAD")
                        .foregroundColor(repo.currentBranch != nil ? .primary : .orange)
                }
            }
            
            if let remote = repo.remoteURL {
                HStack {
                    Text("Remote")
                    Spacer()
                    Text(remote.absoluteString)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            HStack {
                Text("Repository Root")
                Spacer()
                Text(repo.rootPath.path)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
    
    @ViewBuilder
    private var worktreesList: some View {
        ForEach(worktrees) { worktree in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(worktree.branch)
                            .fontWeight(worktree.isMain ? .semibold : .regular)
                        
                        if worktree.isMain {
                            Text("(main)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(worktree.path.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                Text(String(worktree.commitHash.prefix(7)))
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Workspace")
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var workspace = Workspace(
            name: "My Project",
            path: URL(fileURLWithPath: "/Users/dev/projects/my-app"),
            gitBranch: "main"
        )
        
        var body: some View {
            let repo = GitRepository(
                rootPath: URL(fileURLWithPath: "/Users/dev/projects/my-app"),
                remoteURL: URL(string: "https://github.com/user/my-app"),
                currentBranch: "main"
            )
            
            let worktrees = [
                GitWorktree(
                    path: URL(fileURLWithPath: "/Users/dev/projects/my-app"),
                    branch: "main",
                    commitHash: "abc1234567890",
                    isMain: true
                ),
                GitWorktree(
                    path: URL(fileURLWithPath: "/Users/dev/projects/my-app-feature"),
                    branch: "feature/new-ui",
                    commitHash: "def4567890123",
                    isMain: false
                )
            ]
            
            return WorkspaceSettingsView(
                workspace: $workspace,
                repository: repo,
                worktrees: worktrees,
                onDelete: {
                    print("Delete requested")
                }
            )
            .frame(width: 500, height: 600)
        }
    }
    
    return PreviewWrapper()
}
#endif
