#if os(macOS)
import SwiftUI

/// View showing an agent working on a task, with task context header
public struct TaskAgentView: View {
    let task: AgentTask
    @Environment(AgentManager.self) var agentManager
    @Environment(TaskManager.self) var taskManager
    @State private var actionError: String?
    @State private var showStartingCancel: Bool = false

    public init(task: AgentTask) {
        self.task = task
    }

    /// The agent running this task, if any
    private var agent: Agent? {
        guard let agentId = task.agentId else { return nil }
        return agentManager.getAgent(id: agentId)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Task info header
            taskHeader

            if let error = actionError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer()
                    Button("Dismiss") {
                        actionError = nil
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
                .foregroundColor(.red)
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.08))
            }

            Divider()

            // Main content
            if let agent = agent {
                // Agent is running - show the standard agent view
                HSplitView {
                    ChatPanel(agent: agent)
                        .frame(minWidth: 300)

                    CodePanel(agent: agent, workspacePath: task.workspacePath)
                        .frame(minWidth: 200, idealWidth: 320, maxWidth: 500)
                        .id(task.id)
                }
            } else if task.status == .pending {
                // Task created but not started
                TaskPendingView(task: task)
            } else if task.status == .starting {
                // Task is starting up
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Starting task...")
                        .font(.headline)
                    Text("Connecting to agent for \(task.workspacePath.lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if showStartingCancel {
                        Button("Cancel") {
                            taskManager.pauseTask(id: task.id)
                            showStartingCancel = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task(id: task.status) {
                    showStartingCancel = false
                    guard task.status == .starting else { return }
                    try? await Task.sleep(for: .seconds(10))
                    if task.status == .starting {
                        showStartingCancel = true
                    }
                }
            } else if task.status == .paused {
                // Task is paused - show stored messages and file changes with resume action
                TaskPausedView(task: task)
            } else if task.status.isTerminal {
                // Task is completed/failed/cancelled - show summary
                TaskCompletedView(task: task)
            } else if task.status == .working {
                // Working but agent not yet available (reconnecting)
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Reconnecting to agent...")
                        .font(.headline)
                    Text("Resuming session for \(task.workspacePath.lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if showStartingCancel {
                        Button("Cancel") {
                            taskManager.pauseTask(id: task.id)
                            showStartingCancel = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task(id: task.status) {
                    showStartingCancel = false
                    guard task.status == .working else { return }
                    try? await Task.sleep(for: .seconds(10))
                    if task.status == .working && agent == nil {
                        showStartingCancel = true
                    }
                }
            } else {
                // Fallback
                VStack(spacing: 16) {
                    Image(systemName: task.status.iconName)
                        .font(.system(size: 48))
                        .foregroundColor(task.status.displayColor)
                    Text(task.name)
                        .font(.title2)
                    Text("Status: \(task.status.rawValue.capitalized)")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(task.name)
    }

    private var taskHeader: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: task.status.iconName)
                .foregroundColor(task.status.displayColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(task.workspacePath.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let branch = task.gitBranch {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.caption2)
                            Text(branch)
                                .font(.caption2)
                        }
                        .foregroundColor(.purple)
                    }
                }
            }

            Spacer()

            // File changes count
            if !task.fileChanges.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.caption)
                    Text("\(task.fileChanges.count) files changed")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }

            // Attention banner
            if task.status == .needsAttention, let reason = task.attentionReason {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(reason)
                        .font(.caption)
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }

            // Task actions
            taskActionButtons
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var taskActionButtons: some View {
        HStack(spacing: 8) {
            if task.status == .pending {
                Button("Start") {
                    Task {
                        actionError = nil
                        do {
                            try await taskManager.startTask(id: task.id)
                        } catch {
                            actionError = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if task.status == .working || task.status == .needsAttention {
                Button("Pause") {
                    taskManager.pauseTask(id: task.id)
                }
                .controlSize(.small)
            }

            if task.status == .paused {
                if task.agentId == nil && task.sessionId != nil {
                    Button("Re-open") {
                        Task {
                            actionError = nil
                            do {
                                try await taskManager.reopenTask(id: task.id)
                            } catch {
                                actionError = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    Button("Resume") {
                        Task {
                            actionError = nil
                            do {
                                try await taskManager.resumeTask(id: task.id)
                            } catch {
                                actionError = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            if task.status == .working || task.status == .needsAttention || task.status == .paused {
                Button {
                    taskManager.completeTask(id: task.id)
                } label: {
                    Label("Complete", systemImage: "checkmark.circle")
                }
                .controlSize(.small)
                .tint(.green)
            }

            if task.status.isActive || task.status == .paused {
                Button("Cancel") {
                    Task { await taskManager.cancelTask(id: task.id) }
                }
                .foregroundColor(.red)
                .controlSize(.small)
            }
        }
    }
}

/// View shown when a task is pending (not yet started)
struct TaskPendingView: View {
    let task: AgentTask
    @Environment(TaskManager.self) var taskManager
    @State private var isStarting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.circle")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text(task.name)
                .font(.title2)

            Text(task.workspacePath.path)
                .font(.caption)
                .foregroundColor(.secondary)

            if let branch = task.gitBranch {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                    Text(branch)
                }
                .foregroundColor(.purple)
            }

            if isStarting {
                ProgressView("Starting task...")
            } else {
                Button("Start Task") {
                    isStarting = true
                    errorMessage = nil
                    Task {
                        do {
                            try await taskManager.startTask(id: task.id)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        isStarting = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: 400)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// View shown when a task has completed/failed/cancelled
struct TaskCompletedView: View {
    let task: AgentTask
    @Environment(TaskManager.self) var taskManager
    @Environment(AgentManager.self) var agentManager
    @State private var isReopening: Bool = false
    @State private var reopenError: String?

    private var agent: Agent? {
        guard let agentId = task.agentId else { return nil }
        return agentManager.getAgent(id: agentId)
    }

    private var formattedDuration: String? {
        guard let startDate = task.startedAt ?? task.createdAt as Date?,
              let endDate = task.completedAt else { return nil }
        let duration = endDate.timeIntervalSince(startDate)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Compact completion banner
            completionBanner

            Divider()

            // Content area
            if let agent = agent {
                // Task was re-opened and agent is active - show full view
                HSplitView {
                    ChatPanel(agent: agent)
                        .frame(minWidth: 300)

                    CodePanel(agent: agent, workspacePath: task.workspacePath)
                        .frame(minWidth: 200, idealWidth: 320, maxWidth: 500)
                        .id(task.id)
                }
            } else if !task.messages.isEmpty || !task.fileChanges.isEmpty {
                // Show stored messages and file changes
                HSplitView {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(task.messages) { message in
                                ChatMessageView(message: message)
                            }
                        }
                        .padding()
                    }
                    .frame(minWidth: 300)

                    if !task.fileChanges.isEmpty {
                        storedFileChangesView
                    }
                }
            } else {
                // No stored content - show centered summary
                VStack(spacing: 16) {
                    Image(systemName: task.status.iconName)
                        .font(.system(size: 64))
                        .foregroundColor(task.status.displayColor)

                    Text(task.name)
                        .font(.title2)

                    Text("Status: \(task.status.rawValue.capitalized)")
                        .font(.headline)
                        .foregroundColor(task.status.displayColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private var completionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: task.status.iconName)
                .font(.title2)
                .foregroundColor(task.status.displayColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Status: \(task.status.rawValue.capitalized)")
                    .font(.headline)
                    .foregroundColor(task.status.displayColor)

                HStack(spacing: 12) {
                    if let completedAt = task.completedAt {
                        Text("Completed: \(completedAt, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let durationString = formattedDuration {
                        Text("Duration: \(durationString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if !task.messages.isEmpty {
                        Text("\(task.messages.count) message\(task.messages.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if !task.fileChanges.isEmpty {
                        Text("\(task.fileChanges.count) file\(task.fileChanges.count == 1 ? "" : "s") changed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if task.sessionId != nil {
                if isReopening {
                    ProgressView()
                        .controlSize(.small)
                    Text("Re-opening...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button("Re-open Task") {
                        isReopening = true
                        reopenError = nil
                        Task {
                            do {
                                try await taskManager.reopenTask(id: task.id)
                            } catch {
                                reopenError = error.localizedDescription
                            }
                            isReopening = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
        }
        .padding()
        .background(task.status.displayColor.opacity(0.08))

        if let error = reopenError {
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
                .padding(.horizontal)
                .padding(.vertical, 4)
        }
    }

    private var storedFileChangesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Files Changed (\(task.fileChanges.count))")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)

            List(task.fileChanges) { change in
                HStack(spacing: 8) {
                    Image(systemName: change.changeType == .created ? "plus.circle.fill" :
                            change.changeType == .deleted ? "minus.circle.fill" : "pencil.circle.fill")
                        .foregroundColor(change.changeType == .created ? .green :
                                change.changeType == .deleted ? .red : .yellow)
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(change.fileName)
                            .font(.subheadline)
                            .lineLimit(1)
                        if !change.directoryPath.isEmpty {
                            Text(change.directoryPath)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        if change.linesAdded > 0 {
                            Text("+\(change.linesAdded)")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        if change.linesRemoved > 0 {
                            Text("-\(change.linesRemoved)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .frame(minWidth: 200, idealWidth: 320, maxWidth: 500)
    }
}

/// View shown when a task is paused, displaying stored conversation and file changes
struct TaskPausedView: View {
    let task: AgentTask
    @Environment(TaskManager.self) var taskManager
    @Environment(AgentManager.self) var agentManager
    @State private var isResuming: Bool = false
    @State private var resumeError: String?
    @State private var pendingMessage: String?

    private var agent: Agent? {
        guard let agentId = task.agentId else { return nil }
        return agentManager.getAgent(id: agentId)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Resume banner at top
            HStack(spacing: 12) {
                Image(systemName: "pause.circle.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Task Paused")
                        .font(.headline)
                    Text("Resume to continue working with the agent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isResuming {
                    ProgressView()
                        .controlSize(.small)
                    Text("Resuming...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    if task.agentId == nil && task.sessionId != nil {
                        Button("Re-open Task") {
                            isResuming = true
                            resumeError = nil
                            Task {
                                do {
                                    try await taskManager.reopenTask(id: task.id)
                                } catch {
                                    resumeError = error.localizedDescription
                                }
                                isResuming = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    } else {
                        Button("Resume Task") {
                            isResuming = true
                            resumeError = nil
                            Task {
                                do {
                                    try await taskManager.resumeTask(id: task.id)
                                } catch {
                                    resumeError = error.localizedDescription
                                }
                                isResuming = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.1))

            if let error = resumeError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
            }

            Divider()

            // Show content based on agent availability
            if let agent = agent {
                // Agent is still active - show full interactive view
                HSplitView {
                    ChatPanel(agent: agent)
                        .frame(minWidth: 300)

                    CodePanel(agent: agent, workspacePath: task.workspacePath)
                        .frame(minWidth: 200, idealWidth: 320, maxWidth: 500)
                        .id(task.id)
                }
            } else if !task.messages.isEmpty || !task.fileChanges.isEmpty {
                // Show stored content with chat input
                HSplitView {
                    // Messages list with chat input at bottom
                    VStack(spacing: 0) {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(task.messages) { message in
                                    ChatMessageView(message: message)
                                }
                            }
                            .padding()
                        }

                        Divider()

                        ChatInputView { message in
                            resumeAndSend(message: message)
                        }
                        .padding()
                    }
                    .frame(minWidth: 300)

                    // File changes summary
                    if !task.fileChanges.isEmpty {
                        storedFileChangesView
                    }
                }
            } else {
                // No stored content
                VStack(spacing: 16) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.yellow)

                    Text(task.name)
                        .font(.title2)

                    Text("This task is paused. Resume to continue.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func resumeAndSend(message: String) {
        pendingMessage = message
        isResuming = true
        resumeError = nil
        Task {
            do {
                if task.agentId == nil && task.sessionId != nil {
                    try await taskManager.reopenTask(id: task.id)
                } else {
                    try await taskManager.resumeTask(id: task.id)
                }
                // After resume, send the pending message
                if let agentId = task.agentId, let msg = pendingMessage {
                    try await agentManager.sendPrompt(agentId: agentId, prompt: msg)
                    pendingMessage = nil
                }
            } catch {
                resumeError = error.localizedDescription
            }
            isResuming = false
        }
    }

    private var storedFileChangesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Files Changed (\(task.fileChanges.count))")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)

            List(task.fileChanges) { change in
                HStack(spacing: 8) {
                    Image(systemName: change.changeType == .created ? "plus.circle.fill" :
                            change.changeType == .deleted ? "minus.circle.fill" : "pencil.circle.fill")
                        .foregroundColor(change.changeType == .created ? .green :
                                change.changeType == .deleted ? .red : .yellow)
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(change.fileName)
                            .font(.subheadline)
                            .lineLimit(1)
                        if !change.directoryPath.isEmpty {
                            Text(change.directoryPath)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        if change.linesAdded > 0 {
                            Text("+\(change.linesAdded)")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        if change.linesRemoved > 0 {
                            Text("-\(change.linesRemoved)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .frame(minWidth: 200, idealWidth: 320, maxWidth: 500)
    }
}

#Preview {
    let task = AgentTask(
        name: "Test Task",
        status: .pending,
        workspacePath: URL(fileURLWithPath: "/Users/test/Projects/test-project")
    )
    TaskAgentView(task: task)
        .environment(AgentManager())
        .environment(TaskManager())
        .frame(width: 800, height: 600)
}
#endif
