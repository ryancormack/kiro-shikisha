#if os(macOS)
import SwiftUI

/// View shown when workspace is a git repository, allowing worktree creation
public struct WorktreeSelector: View {
    @Environment(AgentManager.self) var agentManager
    
    /// The detected git repository
    let repository: GitRepository
    /// Existing worktrees in the repository
    let worktrees: [GitWorktree]
    /// Callback when a new worktree should be created
    var onCreateWorktree: (String, URL) -> Void
    /// Callback when an existing worktree is selected
    var onSelectWorktree: ((GitWorktree) -> Void)?
    /// Callback when starting an agent in a worktree
    var onStartAgent: ((GitWorktree) -> Void)?
    
    @State private var newBranchName: String = ""
    @State private var selectedWorktree: GitWorktree?
    @State private var useExistingWorktree: Bool = false
    
    public init(
        repository: GitRepository,
        worktrees: [GitWorktree] = [],
        onCreateWorktree: @escaping (String, URL) -> Void,
        onSelectWorktree: ((GitWorktree) -> Void)? = nil,
        onStartAgent: ((GitWorktree) -> Void)? = nil
    ) {
        self.repository = repository
        self.worktrees = worktrees
        self.onCreateWorktree = onCreateWorktree
        self.onSelectWorktree = onSelectWorktree
        self.onStartAgent = onStartAgent
    }
    
    /// Check if a worktree has an active agent
    private func hasActiveAgent(for worktree: GitWorktree) -> Bool {
        agentManager.getAllAgents().contains { agent in
            agent.workspace.path == worktree.path ||
            agent.workspace.gitWorktreePath == worktree.path
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Current branch info
            currentBranchInfo
            
            Divider()
            
            // Worktree options
            worktreeOptions
            
            // Existing worktrees list with Start Agent buttons
            if !worktrees.isEmpty {
                Divider()
                existingWorktreesList
            }
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
    
    @ViewBuilder
    private var existingWorktreesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Existing Worktrees")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            ForEach(worktrees) { worktree in
                WorktreeRow(
                    worktree: worktree,
                    hasActiveAgent: hasActiveAgent(for: worktree),
                    onStartAgent: onStartAgent
                )
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

/// Row displaying a single worktree with optional Start Agent button
struct WorktreeRow: View {
    let worktree: GitWorktree
    let hasActiveAgent: Bool
    var onStartAgent: ((GitWorktree) -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with active indicator
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: worktree.isMain ? "folder.fill" : "arrow.triangle.branch")
                    .foregroundColor(worktree.isMain ? .blue : .purple)
                
                if hasActiveAgent {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        .offset(x: 2, y: 2)
                }
            }
            .frame(width: 24)
            
            // Worktree info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(worktree.branch)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if worktree.isMain {
                        Text("main")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.badgeCornerRadius))
                        Text("running")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.badgeCornerRadius))
                    }
                }
                
                Text(worktree.path.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Start Agent button (only if callback provided and no active agent)
            if let onStartAgent = onStartAgent, !hasActiveAgent {
                Button {
                    onStartAgent(worktree)
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium)
                .fill(hasActiveAgent ? Color.green.opacity(0.05) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium)
                .stroke(hasActiveAgent ? Color.green.opacity(0.2) : Color.clear, lineWidth: 1)
        )
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
        },
        onStartAgent: { worktree in
            print("Start agent in: \(worktree.branch)")
        }
    )
    .environment(AgentManager())
    .frame(width: 400)
}
#endif
