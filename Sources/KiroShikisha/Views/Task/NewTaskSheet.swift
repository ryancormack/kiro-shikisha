#if os(macOS)
import SwiftUI
import AppKit

/// Sheet content for creating a new task
public struct NewTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var appSettings

    @State private var taskName: String = ""
    @State private var selectedDirectory: URL?

    // Git repository detection
    @State private var detectedRepository: GitRepository?
    @State private var isDetectingGit: Bool = false
    @State private var gitBranch: String = ""
    @State private var createWorktree: Bool = false
    @State private var newBranchName: String = ""
    @State private var startImmediately: Bool = true
    @State private var selectedAgentConfigId: UUID?

    private let gitService = GitService()

    /// Callback when task is created
    public var onCreate: (TaskCreationRequest) -> Void

    public init(onCreate: @escaping (TaskCreationRequest) -> Void) {
        self.onCreate = onCreate
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Task")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            // Form content
            ScrollView {
                Form {
                    taskNameSection

                    directorySection

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

                Button("Create Task") {
                    createTask()
                }
                .keyboardShortcut(.return)
                .disabled(!canCreate)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: detectedRepository != nil ? 520 : 400)
    }

    @ViewBuilder
    private var taskNameSection: some View {
        Section {
            TextField("Task Name", text: $taskName)
                .textFieldStyle(.roundedBorder)
        } header: {
            Text("Task Name")
        }
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

                // Branch override
                TextField("Branch (leave empty for current)", text: $gitBranch)
                    .textFieldStyle(.roundedBorder)

                // Worktree option
                Toggle("Create task in new worktree", isOn: $createWorktree)

                if createWorktree {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("New branch name (e.g., feature/my-feature)", text: $newBranchName)
                            .textFieldStyle(.roundedBorder)

                        Text("A new worktree will be created as a sibling directory")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
            Toggle("Start task immediately", isOn: $startImmediately)
            
            if !appSettings.agentConfigurations.isEmpty {
                Picker("Agent Configuration", selection: $selectedAgentConfigId) {
                    Text("Default").tag(UUID?.none)
                    ForEach(appSettings.agentConfigurations) { config in
                        HStack {
                            Text(config.name)
                            if !config.tags.isEmpty {
                                Text(config.tags.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(Optional(config.id))
                    }
                }
            }
        } header: {
            Text("Options")
        }
    }

    private var canCreate: Bool {
        guard selectedDirectory != nil && !taskName.isEmpty else {
            return false
        }

        if createWorktree {
            return !newBranchName.isEmpty
        }

        return true
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose Task Directory"
        panel.message = "Select a directory for this task"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            selectedDirectory = url

            // Detect git repository
            detectGitRepository(at: url)
        }
    }

    private func detectGitRepository(at url: URL) {
        isDetectingGit = true
        detectedRepository = nil

        Task {
            do {
                if let repo = try await gitService.detectGitRepository(at: url) {
                    await MainActor.run {
                        detectedRepository = repo
                        if let branch = repo.currentBranch {
                            gitBranch = branch
                        }
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

    private func createTask() {
        guard let directory = selectedDirectory else { return }

        let branch: String?
        let worktreeBranch: String?
        if createWorktree {
            branch = newBranchName
            worktreeBranch = newBranchName
        } else {
            branch = gitBranch.isEmpty ? detectedRepository?.currentBranch : gitBranch
            worktreeBranch = nil
        }

        let request = TaskCreationRequest(
            name: taskName,
            workspacePath: directory,
            gitBranch: branch,
            useWorktree: createWorktree,
            worktreeBranchName: worktreeBranch,
            startImmediately: startImmediately,
            agentConfigurationId: selectedAgentConfigId
        )

        onCreate(request)
        dismiss()
    }
}

#Preview {
    NewTaskSheet { request in
        print("Created task: \(request.name)")
    }
    .environment(AppSettings())
}
#endif
