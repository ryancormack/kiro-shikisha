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

    // Existing session discovery for the selected directory
    @State private var existingSessions: [SessionMetadata] = []
    @State private var isLoadingSessions: Bool = false
    @State private var showExistingSessions: Bool = true

    private let gitService = GitService()
    private let sessionStorage = SessionStorage()

    /// Callback when task is created from scratch
    public var onCreate: (TaskCreationRequest) -> Void

    /// Callback when user chooses to resume an existing session instead of creating a new task
    public var onResumeSession: ((String, URL) -> Void)?

    public init(
        onCreate: @escaping (TaskCreationRequest) -> Void,
        onResumeSession: ((String, URL) -> Void)? = nil
    ) {
        self.onCreate = onCreate
        self.onResumeSession = onResumeSession
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

                    if !existingSessions.isEmpty || isLoadingSessions {
                        existingSessionsSection
                    }

                    if detectedRepository != nil {
                        gitSection
                    }

                    optionsSection
                }
                .formStyle(.grouped)
            }
            .frame(maxHeight: 480)

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
        .frame(width: 520, height: computedHeight)
    }

    /// Compute the sheet height based on what's visible.
    private var computedHeight: CGFloat {
        var h: CGFloat = 400
        if detectedRepository != nil { h += 140 }
        if !existingSessions.isEmpty { h += 120 }
        return min(h, 720)
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
    private var existingSessionsSection: some View {
        Section {
            if isLoadingSessions {
                HStack {
                    ProgressView().scaleEffect(0.7)
                    Text("Looking for past sessions…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                DisclosureGroup(isExpanded: $showExistingSessions) {
                    ForEach(existingSessions.prefix(5)) { session in
                        Button {
                            resumeSession(session)
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.displayName)
                                        .font(.body)
                                        .lineLimit(1)
                                    if let date = session.lastActivityDate {
                                        Text(date, style: .relative)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                                    .foregroundColor(.accentColor)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 2)
                    }
                    if existingSessions.count > 5 {
                        Text("+ \(existingSessions.count - 5) more — use File > Load Session… to browse all")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } label: {
                    Label("Resume an existing session for this directory (\(existingSessions.count))", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline)
                }
            }
        } header: {
            Text("Past Sessions")
        } footer: {
            Text("Past kiro sessions found for this directory. Pick one to resume where you left off, or fill in the form below to start fresh.")
                .font(.caption)
                .foregroundColor(.secondary)
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
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Agent Configuration", selection: $selectedAgentConfigId) {
                        defaultPickerLabel
                            .tag(UUID?.none)
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
                    Text("Choose which AI agent profile to use for this task.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No agent profiles configured. The default agent will be used.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("You can add agent profiles in Settings > Agents.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Options")
        }
    }
    
    @ViewBuilder
    private var defaultPickerLabel: some View {
        if let defaultConfig = appSettings.defaultAgentConfiguration {
            Text("Use Default (\(defaultConfig.name))")
        } else {
            Text("Use Default Configuration")
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

            // Discover past sessions for this directory
            loadExistingSessions(for: url)
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

    /// Look up past kiro-cli sessions for the selected directory so the user can resume one.
    private func loadExistingSessions(for url: URL) {
        isLoadingSessions = true
        existingSessions = []
        Task {
            let found = sessionStorage.getSessionsForWorkspace(path: url)
                .sorted { ($0.lastActivityDate ?? .distantPast) > ($1.lastActivityDate ?? .distantPast) }
            await MainActor.run {
                self.existingSessions = found
                self.isLoadingSessions = false
            }
        }
    }

    private func resumeSession(_ session: SessionMetadata) {
        let cwd = URL(fileURLWithPath: session.cwd)
        onResumeSession?(session.sessionId, cwd)
        dismiss()
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
