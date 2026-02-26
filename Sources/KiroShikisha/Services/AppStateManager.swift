#if os(macOS)
import Foundation

/// Represents a workspace-session association with path verification
public struct SessionAssociation: Codable, Sendable, Equatable {
    /// The session ID
    public let sessionId: String
    /// The working directory path when the session was associated
    public let cwd: String
    
    public init(sessionId: String, cwd: String) {
        self.sessionId = sessionId
        self.cwd = cwd
    }
}

/// Manages persistent application state including workspaces and session associations
@Observable
@MainActor
public final class AppStateManager {
    // MARK: - Persisted State
    
    /// All workspaces known to the app
    public private(set) var workspaces: [Workspace] = []
    
    /// Currently selected workspace ID
    public var selectedWorkspaceId: UUID?
    
    /// Maps workspace IDs to their session association (sessionId + cwd)
    public private(set) var workspaceSessionAssociations: [UUID: SessionAssociation] = [:]

    /// PIDs of kiro-cli processes spawned by this app (saved on quit, killed on next launch)
    public var ownedProcessPids: [Int32] = []
    
    // MARK: - Private Properties
    
    private let userDefaults: UserDefaults
    private let storageKey = "com.kiroshikisha.appState"
    
    // MARK: - Codable State Container
    
    private struct PersistedState: Codable {
        var workspaces: [Workspace]
        var selectedWorkspaceId: UUID?
        var workspaceSessionAssociations: [UUID: SessionAssociation]
        var ownedProcessPids: [Int32]?
        
        // Support migration from old format (String-only session IDs)
        private var legacySessionAssociations: [UUID: String]?
        
        enum CodingKeys: String, CodingKey {
            case workspaces
            case selectedWorkspaceId
            case workspaceSessionAssociations
            case ownedProcessPids
        }
        
        init(
            workspaces: [Workspace],
            selectedWorkspaceId: UUID?,
            workspaceSessionAssociations: [UUID: SessionAssociation],
            ownedProcessPids: [Int32]?
        ) {
            self.workspaces = workspaces
            self.selectedWorkspaceId = selectedWorkspaceId
            self.workspaceSessionAssociations = workspaceSessionAssociations
            self.ownedProcessPids = ownedProcessPids
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            workspaces = try container.decode([Workspace].self, forKey: .workspaces)
            selectedWorkspaceId = try container.decodeIfPresent(UUID.self, forKey: .selectedWorkspaceId)
            ownedProcessPids = try container.decodeIfPresent([Int32].self, forKey: .ownedProcessPids)
            
            // Try new format first, fall back to legacy format
            if let newAssociations = try? container.decode([UUID: SessionAssociation].self, forKey: .workspaceSessionAssociations) {
                workspaceSessionAssociations = newAssociations
            } else if let legacyAssociations = try? container.decode([UUID: String].self, forKey: .workspaceSessionAssociations) {
                // Migrate from old format - we don't have cwd info, so use empty string
                // The validation will clean up any mismatches on load
                workspaceSessionAssociations = legacyAssociations.mapValues { sessionId in
                    SessionAssociation(sessionId: sessionId, cwd: "")
                }
            } else {
                workspaceSessionAssociations = [:]
            }
        }
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
            workspaceSessionAssociations: workspaceSessionAssociations,
            ownedProcessPids: ownedProcessPids
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
            
            // Validate stored session associations
            validateStoredSessionAssociations()
        } catch {
            print("Failed to load app state: \(error)")
        }
    }
    
    /// Validates stored session associations and removes invalid entries
    /// Call this after loading state to clean up stale associations
    public func validateStoredSessionAssociations() {
        let sessionStorage = SessionStorage()
        var invalidWorkspaceIds: [UUID] = []
        
        for (workspaceId, association) in workspaceSessionAssociations {
            let validationResult = sessionStorage.validateSession(sessionId: association.sessionId)
            switch validationResult {
            case .valid:
                // Session is valid - also verify cwd matches if we have workspace info
                if let workspace = workspaces.first(where: { $0.id == workspaceId }) {
                    // Verify the session's cwd matches the workspace path
                    if !sessionStorage.sessionMatchesWorkspacePath(sessionId: association.sessionId, workspacePath: workspace.path) {
                        print("[AppStateManager] Removing session association for workspace \(workspaceId): session \(association.sessionId) cwd does not match workspace path \(workspace.path.path)")
                        invalidWorkspaceIds.append(workspaceId)
                    }
                }
            case .invalid(let reason):
                print("[AppStateManager] Removing invalid session association for workspace \(workspaceId): session \(association.sessionId) is invalid - \(reason)")
                invalidWorkspaceIds.append(workspaceId)
            case .notFound:
                print("[AppStateManager] Removing invalid session association for workspace \(workspaceId): session \(association.sessionId) not found")
                invalidWorkspaceIds.append(workspaceId)
            }
        }
        
        // Remove invalid associations
        if !invalidWorkspaceIds.isEmpty {
            for workspaceId in invalidWorkspaceIds {
                workspaceSessionAssociations.removeValue(forKey: workspaceId)
            }
            saveState()
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
    
    /// Associates a session with a workspace, including the session's cwd for path verification
    /// - Parameters:
    ///   - workspaceId: The workspace UUID to associate
    ///   - sessionId: The session ID to associate
    ///   - cwd: The working directory path of the session
    public func updateSessionForWorkspace(_ workspaceId: UUID, sessionId: String, cwd: String) {
        workspaceSessionAssociations[workspaceId] = SessionAssociation(sessionId: sessionId, cwd: cwd)
        saveState()
    }
    
    /// Gets the last session ID for a workspace (without path verification)
    /// Use getValidSessionForWorkspace for path-verified retrieval
    public func getLastSessionForWorkspace(_ workspaceId: UUID) -> String? {
        workspaceSessionAssociations[workspaceId]?.sessionId
    }
    
    /// Gets a valid session for a workspace, verifying the session's cwd matches the workspace path
    /// - Parameters:
    ///   - workspaceId: The workspace UUID to get session for
    ///   - workspacePath: The workspace path to verify against
    /// - Returns: The session ID if valid and path matches, nil otherwise
    public func getValidSessionForWorkspace(_ workspaceId: UUID, workspacePath: URL) -> String? {
        guard let association = workspaceSessionAssociations[workspaceId] else {
            return nil
        }
        
        // Verify the session's cwd matches the workspace path using canonical comparison
        let sessionStorage = SessionStorage()
        
        // First verify session exists and is valid
        guard sessionStorage.validateSession(sessionId: association.sessionId) == .valid else {
            // Clear stale association
            print("[AppStateManager] Clearing invalid session association for workspace \(workspaceId)")
            workspaceSessionAssociations.removeValue(forKey: workspaceId)
            saveState()
            return nil
        }
        
        // Verify path matches
        if !sessionStorage.sessionMatchesWorkspacePath(sessionId: association.sessionId, workspacePath: workspacePath) {
            // Session exists but was created for a different workspace path
            print("[AppStateManager] Session \(association.sessionId) cwd does not match workspace \(workspacePath.path), clearing association")
            workspaceSessionAssociations.removeValue(forKey: workspaceId)
            saveState()
            return nil
        }
        
        return association.sessionId
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
