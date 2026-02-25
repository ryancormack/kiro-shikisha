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
    
    /// Maps workspace IDs to their last used session ID
    public private(set) var workspaceSessionAssociations: [UUID: String] = [:]
    
    // MARK: - Private Properties
    
    private let userDefaults: UserDefaults
    private let storageKey = "com.kiroshikisha.appState"
    
    // MARK: - Codable State Container
    
    private struct PersistedState: Codable {
        var workspaces: [Workspace]
        var selectedWorkspaceId: UUID?
        var workspaceSessionAssociations: [UUID: String]
    }
    
    // MARK: - Initialization
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadState()
    }
    
    // MARK: - Persistence
    
    /// Saves the current state to UserDefaults
    public func saveState() {
        let state = PersistedState(
            workspaces: workspaces,
            selectedWorkspaceId: selectedWorkspaceId,
            workspaceSessionAssociations: workspaceSessionAssociations
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
}
#endif
