#if os(macOS)
import Foundation

/// Manages persistent application state including workspaces and session associations
@Observable
@MainActor
public final class AppStateManager {
    // MARK: - Persisted State
    
    /// All workspaces known to the app
    public private(set) var workspaces: [Workspace] = []
    
    /// Currently selected workspace ID
    public var selectedWorkspaceId: UUID?
    
    /// Currently selected task ID
    public var selectedTaskId: UUID?
    
    /// Maps workspace IDs to their last used session ID
    public private(set) var workspaceSessionAssociations: [UUID: String] = [:]

    /// PIDs of kiro-cli processes spawned by this app (saved on quit, killed on next launch)
    public var ownedProcessPids: [Int32] = []
    
    // MARK: - Private Properties
    
    private let userDefaults: UserDefaults
    private let storageKey = "com.kiroshikisha.appState"
    private var saveWorkItem: DispatchWorkItem?
    
    // MARK: - Codable State Container
    
    /// Serializable entry for persisting task metadata
    public struct TaskPersistenceEntry: Codable, Sendable {
        public var id: UUID
        public var name: String
        public var statusRawValue: String
        public var workspacePath: String
        public var gitBranch: String?
        public var sessionId: String?
        public var createdAt: Date
        public var completedAt: Date?
        public var lastActivityAt: Date?

        public init(
            id: UUID,
            name: String,
            statusRawValue: String,
            workspacePath: String,
            gitBranch: String? = nil,
            sessionId: String? = nil,
            createdAt: Date,
            completedAt: Date? = nil,
            lastActivityAt: Date? = nil
        ) {
            self.id = id
            self.name = name
            self.statusRawValue = statusRawValue
            self.workspacePath = workspacePath
            self.gitBranch = gitBranch
            self.sessionId = sessionId
            self.createdAt = createdAt
            self.completedAt = completedAt
            self.lastActivityAt = lastActivityAt
        }
    }
    
    /// Task entries to be included in the next save
    public var taskEntriesToPersist: [TaskPersistenceEntry] = []
    
    /// Task entries loaded from the last persisted state
    public private(set) var persistedTaskEntries: [TaskPersistenceEntry] = []
    
    private struct PersistedState: Codable {
        var workspaces: [Workspace]
        var selectedWorkspaceId: UUID?
        var workspaceSessionAssociations: [UUID: String]
        var ownedProcessPids: [Int32]?
        var selectedTaskId: UUID?
        var taskEntries: [TaskPersistenceEntry]?
    }
    
    // MARK: - Initialization
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadState()
    }
    
    // MARK: - Persistence
    
    /// Converts tasks to persistence entries and schedules a debounced save
    public func persistTasks(_ tasks: [AgentTask]) {
        taskEntriesToPersist = tasks.map { task in
            TaskPersistenceEntry(
                id: task.id,
                name: task.name,
                statusRawValue: task.status.rawValue,
                workspacePath: task.workspacePath.path,
                gitBranch: task.gitBranch,
                sessionId: task.sessionId,
                createdAt: task.createdAt,
                completedAt: task.completedAt,
                lastActivityAt: task.lastActivityAt
            )
        }
        scheduleSave()
    }

    /// Cancels any pending debounced save and saves state synchronously
    public func saveImmediately() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        saveState()
    }

    /// Schedules a debounced save after 0.5 seconds, cancelling any pending save
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveState()
        }
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    /// Saves the current state to UserDefaults
    public func saveState() {
        let state = PersistedState(
            workspaces: workspaces,
            selectedWorkspaceId: selectedWorkspaceId,
            workspaceSessionAssociations: workspaceSessionAssociations,
            ownedProcessPids: ownedProcessPids,
            selectedTaskId: selectedTaskId,
            taskEntries: taskEntriesToPersist
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            print("Failed to save app state: \(error)")
        }
    }
    
    /// Loads state from UserDefaults
    public func loadState() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(PersistedState.self, from: data)
            workspaces = state.workspaces
            selectedWorkspaceId = state.selectedWorkspaceId
            workspaceSessionAssociations = state.workspaceSessionAssociations
            ownedProcessPids = state.ownedProcessPids ?? []
            selectedTaskId = state.selectedTaskId
            persistedTaskEntries = state.taskEntries ?? []
        } catch {
            print("Failed to load app state: \(error)")
        }
    }
    
    // MARK: - Workspace Management
    
    /// Adds a new workspace and persists state
    /// Returns false if a workspace with the same path already exists
    @discardableResult
    public func addWorkspace(_ workspace: Workspace) -> Bool {
        if workspaces.contains(where: { $0.path == workspace.path }) {
            return false
        }
        workspaces.append(workspace)
        saveState()
        return true
    }
    
    /// Removes a workspace by ID and persists state
    public func removeWorkspace(id: UUID) {
        workspaces.removeAll { $0.id == id }
        workspaceSessionAssociations.removeValue(forKey: id)
        if selectedWorkspaceId == id {
            selectedWorkspaceId = nil
        }
        saveState()
    }
    
    /// Updates a workspace and persists state
    public func updateWorkspace(_ workspace: Workspace) {
        if let index = workspaces.firstIndex(where: { $0.id == workspace.id }) {
            workspaces[index] = workspace
            saveState()
        }
    }
    
    /// Updates the last accessed time for a workspace
    public func touchWorkspace(id: UUID) {
        if let index = workspaces.firstIndex(where: { $0.id == id }) {
            workspaces[index].lastAccessedAt = Date()
            saveState()
        }
    }
    
    // MARK: - Session Association Management
    
    /// Associates a session with a workspace
    public func updateSessionForWorkspace(_ workspaceId: UUID, sessionId: String) {
        workspaceSessionAssociations[workspaceId] = sessionId
        saveState()
    }
    
    /// Gets the last session ID for a workspace
    public func getLastSessionForWorkspace(_ workspaceId: UUID) -> String? {
        workspaceSessionAssociations[workspaceId]
    }
    
    /// Removes session association for a workspace
    public func clearSessionForWorkspace(_ workspaceId: UUID) {
        workspaceSessionAssociations.removeValue(forKey: workspaceId)
        saveState()
    }
    
    // MARK: - Selection Management
    
    /// Selects a workspace by ID and persists state
    public func selectWorkspace(_ id: UUID?) {
        selectedWorkspaceId = id
        if let id = id {
            touchWorkspace(id: id)
        }
        saveState()
    }
    
    // MARK: - Task Selection Management
    
    /// Selects a task by ID and persists state
    public func selectTask(_ id: UUID?) {
        selectedTaskId = id
        saveState()
    }
}

#else

import Foundation

// Stub implementation for non-macOS platforms (Linux)
#if canImport(Observation)
import Observation

@Observable
@MainActor
public final class AppStateManager {
    public struct TaskPersistenceEntry: Codable, Sendable {
        public var id: UUID
        public var name: String
        public var statusRawValue: String
        public var workspacePath: String
        public var gitBranch: String?
        public var sessionId: String?
        public var createdAt: Date
        public var completedAt: Date?
        public var lastActivityAt: Date?

        public init(
            id: UUID,
            name: String,
            statusRawValue: String,
            workspacePath: String,
            gitBranch: String? = nil,
            sessionId: String? = nil,
            createdAt: Date,
            completedAt: Date? = nil,
            lastActivityAt: Date? = nil
        ) {
            self.id = id
            self.name = name
            self.statusRawValue = statusRawValue
            self.workspacePath = workspacePath
            self.gitBranch = gitBranch
            self.sessionId = sessionId
            self.createdAt = createdAt
            self.completedAt = completedAt
            self.lastActivityAt = lastActivityAt
        }
    }

    public private(set) var workspaces: [Workspace] = []
    public var selectedWorkspaceId: UUID?
    public var selectedTaskId: UUID?
    public private(set) var workspaceSessionAssociations: [UUID: String] = [:]
    public var ownedProcessPids: [Int32] = []
    public var taskEntriesToPersist: [TaskPersistenceEntry] = []
    public private(set) var persistedTaskEntries: [TaskPersistenceEntry] = []

    public init(userDefaults: Any? = nil) {}

    public func saveState() {}
    public func loadState() {}
    public func persistTasks(_ tasks: [AgentTask]) {}
    public func saveImmediately() {}

    @discardableResult
    public func addWorkspace(_ workspace: Workspace) -> Bool { return false }
    public func removeWorkspace(id: UUID) {}
    public func updateWorkspace(_ workspace: Workspace) {}
    public func touchWorkspace(id: UUID) {}
    public func updateSessionForWorkspace(_ workspaceId: UUID, sessionId: String) {}
    public func getLastSessionForWorkspace(_ workspaceId: UUID) -> String? { return nil }
    public func clearSessionForWorkspace(_ workspaceId: UUID) {}
    public func selectWorkspace(_ id: UUID?) {}
    public func selectTask(_ id: UUID?) {}
}
#else
@MainActor
public final class AppStateManager {
    public struct TaskPersistenceEntry: Codable, Sendable {
        public var id: UUID
        public var name: String
        public var statusRawValue: String
        public var workspacePath: String
        public var gitBranch: String?
        public var sessionId: String?
        public var createdAt: Date
        public var completedAt: Date?
        public var lastActivityAt: Date?

        public init(
            id: UUID,
            name: String,
            statusRawValue: String,
            workspacePath: String,
            gitBranch: String? = nil,
            sessionId: String? = nil,
            createdAt: Date,
            completedAt: Date? = nil,
            lastActivityAt: Date? = nil
        ) {
            self.id = id
            self.name = name
            self.statusRawValue = statusRawValue
            self.workspacePath = workspacePath
            self.gitBranch = gitBranch
            self.sessionId = sessionId
            self.createdAt = createdAt
            self.completedAt = completedAt
            self.lastActivityAt = lastActivityAt
        }
    }

    public private(set) var workspaces: [Workspace] = []
    public var selectedWorkspaceId: UUID?
    public var selectedTaskId: UUID?
    public private(set) var workspaceSessionAssociations: [UUID: String] = [:]
    public var ownedProcessPids: [Int32] = []
    public var taskEntriesToPersist: [TaskPersistenceEntry] = []
    public private(set) var persistedTaskEntries: [TaskPersistenceEntry] = []

    public init(userDefaults: Any? = nil) {}

    public func saveState() {}
    public func loadState() {}
    public func persistTasks(_ tasks: [AgentTask]) {}
    public func saveImmediately() {}

    @discardableResult
    public func addWorkspace(_ workspace: Workspace) -> Bool { return false }
    public func removeWorkspace(id: UUID) {}
    public func updateWorkspace(_ workspace: Workspace) {}
    public func touchWorkspace(id: UUID) {}
    public func updateSessionForWorkspace(_ workspaceId: UUID, sessionId: String) {}
    public func getLastSessionForWorkspace(_ workspaceId: UUID) -> String? { return nil }
    public func clearSessionForWorkspace(_ workspaceId: UUID) {}
    public func selectWorkspace(_ id: UUID?) {}
    public func selectTask(_ id: UUID?) {}
}
#endif

#endif
