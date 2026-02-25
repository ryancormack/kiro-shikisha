#if os(macOS)
import SwiftUI
import AppKit

/// Sheet content for creating a new workspace
public struct NewWorkspaceSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDirectory: URL?
    @State private var workspaceName: String = ""
    @State private var startAgentImmediately: Bool = false
    
    // Git repository detection
    @State private var detectedRepository: GitRepository?
    @State private var worktrees: [GitWorktree] = []
    @State private var isDetectingGit: Bool = false
    @State private var createWorktree: Bool = false
    @State private var newBranchName: String = ""
    @State private var worktreeCreationError: String?
    
    private let gitService = GitService()
    
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
            ScrollView {
                Form {
                    directorySection
                    
                    nameSection
                    
                    if detectedRepository != nil {
                        gitSection
                    }
                    
                    optionsSection
                }
                .formStyle(.grouped)
            }
            .frame(maxHeight: 400)
            
            Divider()
            
            // Footer buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button(createButtonLabel) {
                    createWorkspace()
                }
                .keyboardShortcut(.return)
                .disabled(!canCreate)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: detectedRepository != nil ? 480 : 320)
    }
    
    @ViewBuilder
    private var directorySection: some View {
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
            
            if isDetectingGit {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Detecting git repository...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Directory")
        }
    }
    
    @ViewBuilder
    private var nameSection: some View {
        Section {
            TextField("Workspace Name", text: $workspaceName)
                .textFieldStyle(.roundedBorder)
        } header: {
            Text("Name")
        }
    }
    
    @ViewBuilder
    private var gitSection: some View {
        if let repo = detectedRepository {
            Section {
                // Repository info
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(.purple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Git Repository Detected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let branch = repo.currentBranch {
                            Text("Current branch: \(branch)")
                        } else {
                            Text("Detached HEAD")
                                .foregroundColor(.orange)
                        }
                    }
                    Spacer()
                }
                
                // Worktree option
                Toggle("Create workspace in new worktree", isOn: $createWorktree)
                
                if createWorktree {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Branch name (e.g., feature/my-feature)", text: $newBranchName)
                            .textFieldStyle(.roundedBorder)
                        
                        if !newBranchName.isEmpty && !isValidBranchName {
                            Text("Invalid branch name")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        if let error = worktreeCreationError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Text("A new worktree will be created as a sibling directory")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Show existing worktrees if any
                if !worktrees.isEmpty {
                    DisclosureGroup("Existing Worktrees (\(worktrees.count))") {
                        ForEach(worktrees) { worktree in
                            HStack {
                                Text(worktree.branch)
                                    .fontWeight(worktree.isMain ? .semibold : .regular)
                                if worktree.isMain {
                                    Text("(main)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(String(worktree.commitHash.prefix(7)))
                                    .font(.caption)
                                    .fontDesign(.monospaced)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Git")
            }
        }
    }
    
    @ViewBuilder
    private var optionsSection: some View {
        Section {
            Toggle("Start agent immediately", isOn: $startAgentImmediately)
        }
    }
    
    private var createButtonLabel: String {
        if createWorktree && !newBranchName.isEmpty {
            return "Create Worktree & Workspace"
        }
        return "Create Workspace"
    }
    
    private var canCreate: Bool {
        guard selectedDirectory != nil && !workspaceName.isEmpty else {
            return false
        }
        
        // If creating worktree, need valid branch name
        if createWorktree {
            return !newBranchName.isEmpty && isValidBranchName
        }
        
        return true
    }
    
    private var isValidBranchName: Bool {
        let invalidPatterns = ["..", " ", "~", "^", ":", "\\", "?", "*", "[", "@{"]
        let trimmed = newBranchName.trimmingCharacters(in: .whitespaces)
        
        guard !trimmed.isEmpty else { return false }
        guard !trimmed.hasPrefix("/") && !trimmed.hasSuffix("/") else { return false }
        guard !trimmed.hasPrefix(".") && !trimmed.hasSuffix(".") else { return false }
        guard !trimmed.hasSuffix(".lock") else { return false }
        
        for pattern in invalidPatterns {
            if trimmed.contains(pattern) {
                return false
            }
        }
        
        return true
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
            
            // Detect git repository
            detectGitRepository(at: url)
        }
    }
    
    private func detectGitRepository(at url: URL) {
        isDetectingGit = true
        detectedRepository = nil
        worktrees = []
        
        Task {
            do {
                if let repo = try await gitService.detectGitRepository(at: url) {
                    let fetchedWorktrees = try await gitService.listWorktrees(repository: repo)
                    
                    await MainActor.run {
                        detectedRepository = repo
                        worktrees = fetchedWorktrees
                        isDetectingGit = false
                    }
                } else {
                    await MainActor.run {
                        isDetectingGit = false
                    }
                }
            } catch {
                await MainActor.run {
                    isDetectingGit = false
                }
            }
        }
    }
    
    private func createWorkspace() {
        guard let directory = selectedDirectory else { return }
        
        if createWorktree, let repo = detectedRepository {
            // Create worktree first
            createWorktreeAndWorkspace(repository: repo, from: directory)
        } else {
            // Create regular workspace
            let workspace = Workspace(
                name: workspaceName,
                path: directory,
                gitRepository: detectedRepository?.remoteURL,
                gitBranch: detectedRepository?.currentBranch
            )
            
            onCreate(workspace)
            dismiss()
        }
    }
    
    private func createWorktreeAndWorkspace(repository: GitRepository, from originalDirectory: URL) {
        worktreeCreationError = nil
        
        // Generate worktree path as sibling directory
        let worktreePath = repository.rootPath
            .deletingLastPathComponent()
            .appendingPathComponent("\(repository.rootPath.lastPathComponent)-\(newBranchName.replacingOccurrences(of: "/", with: "-"))")
        
        Task {
            do {
                let worktree = try await gitService.createWorktree(
                    repository: repository,
                    branch: newBranchName,
                    path: worktreePath
                )
                
                await MainActor.run {
                    // Create workspace pointing to the new worktree
                    let workspace = Workspace(
                        name: workspaceName,
                        path: worktree.path,
                        gitRepository: repository.remoteURL,
                        gitBranch: worktree.branch,
                        gitWorktreePath: worktree.path
                    )
                    
                    onCreate(workspace)
                    dismiss()
                }
            } catch let error as GitServiceError {
                await MainActor.run {
                    switch error {
                    case .worktreeCreationFailed(let message):
                        worktreeCreationError = "Failed to create worktree: \(message)"
                    case .commandFailed(_, _, let stderr):
                        worktreeCreationError = "Git error: \(stderr)"
                    default:
                        worktreeCreationError = "Failed to create worktree"
                    }
                }
            } catch {
                await MainActor.run {
                    worktreeCreationError = "Failed to create worktree: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    NewWorkspaceSheet { workspace in
        print("Created workspace: \(workspace.name)")
    }
}
#endif
