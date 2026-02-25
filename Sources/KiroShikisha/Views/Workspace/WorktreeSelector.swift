#if os(macOS)
import SwiftUI

/// View shown when workspace is a git repository, allowing worktree creation
public struct WorktreeSelector: View {
    /// The detected git repository
    let repository: GitRepository
    /// Existing worktrees in the repository
    let worktrees: [GitWorktree]
    /// Callback when a new worktree should be created
    var onCreateWorktree: (String, URL) -> Void
    /// Callback when an existing worktree is selected
    var onSelectWorktree: ((GitWorktree) -> Void)?
    
    @State private var newBranchName: String = ""
    @State private var selectedWorktree: GitWorktree?
    @State private var useExistingWorktree: Bool = false
    
    public init(
        repository: GitRepository,
        worktrees: [GitWorktree] = [],
        onCreateWorktree: @escaping (String, URL) -> Void,
        onSelectWorktree: ((GitWorktree) -> Void)? = nil
    ) {
        self.repository = repository
        self.worktrees = worktrees
        self.onCreateWorktree = onCreateWorktree
        self.onSelectWorktree = onSelectWorktree
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Current branch info
            currentBranchInfo
            
            Divider()
            
            // Worktree options
            worktreeOptions
        }
        .padding()
    }
    
    @ViewBuilder
    private var currentBranchInfo: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Git Repository")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let branch = repository.currentBranch {
                    Text(branch)
                        .font(.headline)
                } else {
                    Text("Detached HEAD")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            if let remote = repository.remoteURL {
                Text(remote.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var worktreeOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start Agent in Worktree")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            // Option: Create new worktree
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Use existing worktree", isOn: $useExistingWorktree)
                    .disabled(worktrees.filter { !$0.isMain }.isEmpty)
                
                if useExistingWorktree {
                    existingWorktreePicker
                } else {
                    newWorktreeForm
                }
            }
        }
    }
    
    @ViewBuilder
    private var newWorktreeForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New branch name:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                TextField("feature/my-feature", text: $newBranchName)
                    .textFieldStyle(.roundedBorder)
                
                Button("Create Worktree") {
                    createNewWorktree()
                }
                .disabled(newBranchName.isEmpty || !isValidBranchName)
                .buttonStyle(.borderedProminent)
            }
            
            if !newBranchName.isEmpty && !isValidBranchName {
                Text("Invalid branch name")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    @ViewBuilder
    private var existingWorktreePicker: some View {
        let linkedWorktrees = worktrees.filter { !$0.isMain }
        
        if linkedWorktrees.isEmpty {
            Text("No existing worktrees found")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Select worktree:", selection: $selectedWorktree) {
                    Text("Select...").tag(nil as GitWorktree?)
                    ForEach(linkedWorktrees) { worktree in
                        HStack {
                            Text(worktree.branch)
                            Text("(\(worktree.path.lastPathComponent))")
                                .foregroundColor(.secondary)
                        }
                        .tag(worktree as GitWorktree?)
                    }
                }
                .pickerStyle(.menu)
                
                if let worktree = selectedWorktree {
                    Button("Use This Worktree") {
                        onSelectWorktree?(worktree)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    private var isValidBranchName: Bool {
        // Basic git branch name validation
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
    
    private func createNewWorktree() {
        guard isValidBranchName else { return }
        
        // Create worktree path as sibling directory to the repo root
        let worktreePath = repository.rootPath
            .deletingLastPathComponent()
            .appendingPathComponent("\(repository.rootPath.lastPathComponent)-\(newBranchName.replacingOccurrences(of: "/", with: "-"))")
        
        onCreateWorktree(newBranchName, worktreePath)
    }
}

#Preview {
    let repo = GitRepository(
        rootPath: URL(fileURLWithPath: "/Users/dev/projects/my-app"),
        remoteURL: URL(string: "https://github.com/user/my-app"),
        currentBranch: "main"
    )
    
    let worktrees = [
        GitWorktree(
            path: URL(fileURLWithPath: "/Users/dev/projects/my-app"),
            branch: "main",
            commitHash: "abc123",
            isMain: true
        ),
        GitWorktree(
            path: URL(fileURLWithPath: "/Users/dev/projects/my-app-feature"),
            branch: "feature/new-ui",
            commitHash: "def456",
            isMain: false
        )
    ]
    
    return WorktreeSelector(
        repository: repo,
        worktrees: worktrees,
        onCreateWorktree: { branch, path in
            print("Create worktree: \(branch) at \(path)")
        },
        onSelectWorktree: { worktree in
            print("Selected worktree: \(worktree.branch)")
        }
    )
    .frame(width: 400)
}
#endif
