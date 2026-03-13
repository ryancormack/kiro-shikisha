import Foundation

/// Metadata for a stored Kiro session
public struct SessionMetadata: Codable, Identifiable, Sendable {
    /// The session identifier
    public let sessionId: String
    /// Working directory for the session
    public let cwd: String
    /// User-provided session name (optional)
    public var sessionName: String?
    /// When the session was created
    public let createdAt: Date?
    /// When the session was last modified
    public let lastModified: Date?
    
    public var id: String { sessionId }
    
    /// Display name for the session - returns sessionName if set, otherwise last path component of cwd
    public var displayName: String {
        if let name = sessionName, !name.isEmpty {
            return name
        }
        return URL(fileURLWithPath: cwd).lastPathComponent
    }
    
    /// Whether this session has a custom name
    public var hasCustomName: Bool {
        sessionName != nil && !(sessionName?.isEmpty ?? true)
    }
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd
        case sessionName = "session_name"
        case createdAt = "created_at"
        case lastModified = "last_modified"
    }
    
    public init(
        sessionId: String,
        cwd: String,
        sessionName: String? = nil,
        createdAt: Date? = nil,
        lastModified: Date? = nil
    ) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.sessionName = sessionName
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        sessionId = try container.decode(String.self, forKey: .sessionId)
        cwd = try container.decode(String.self, forKey: .cwd)
        sessionName = try container.decodeIfPresent(String.self, forKey: .sessionName)
        
        // Handle date decoding with flexibility for different formats
        if let timestamp = try? container.decode(Double.self, forKey: .createdAt) {
            createdAt = Date(timeIntervalSince1970: timestamp)
        } else if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: dateString)
        } else {
            createdAt = nil
        }
        
        if let timestamp = try? container.decode(Double.self, forKey: .lastModified) {
            lastModified = Date(timeIntervalSince1970: timestamp)
        } else if let dateString = try? container.decode(String.self, forKey: .lastModified) {
            lastModified = ISO8601DateFormatter().date(from: dateString)
        } else {
            lastModified = nil
        }
    }
}

/// Service for discovering and loading existing Kiro sessions from disk
public final class SessionStorage: Sendable {
    /// Directory containing session files
    public let sessionsDirectory: URL
    
    /// File manager for file operations
    private nonisolated(unsafe) let fileManager: FileManager
    
    /// Initialize with the default sessions directory (~/.kiro/sessions/cli/)
    public init() {
        self.fileManager = FileManager.default
        self.sessionsDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".kiro")
            .appendingPathComponent("sessions")
            .appendingPathComponent("cli")
    }
    
    /// Initialize with a custom sessions directory
    /// - Parameter sessionsDirectory: Custom directory to use for sessions
    public init(sessionsDirectory: URL) {
        self.fileManager = FileManager.default
        self.sessionsDirectory = sessionsDirectory
    }
    
    /// List all available sessions
    /// - Returns: Array of session metadata for all discovered sessions
    public func listAllSessions() -> [SessionMetadata] {
        var sessions: [SessionMetadata] = []
        
        guard fileManager.fileExists(atPath: sessionsDirectory.path) else {
            return sessions
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: sessionsDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            let jsonFiles = contents.filter { $0.pathExtension == "json" }
            
            for fileURL in jsonFiles {
                if let metadata = loadSessionMetadata(from: fileURL) {
                    sessions.append(metadata)
                }
            }
        } catch {
            // Return empty array if directory cannot be read
        }
        
        return sessions
    }
    
    /// Get sessions for a specific workspace path
    /// - Parameter path: URL of the workspace directory
    /// - Returns: Array of session metadata for sessions matching the workspace
    public func getSessionsForWorkspace(path: URL) -> [SessionMetadata] {
        let allSessions = listAllSessions()
        let workspacePath = path.path
        
        return allSessions.filter { session in
            // Normalize paths for comparison
            let sessionPath = URL(fileURLWithPath: session.cwd).standardizedFileURL.path
            let targetPath = URL(fileURLWithPath: workspacePath).standardizedFileURL.path
            return sessionPath == targetPath
        }
    }
    
    /// Load session events from a JSONL file
    /// - Parameter sessionId: The session ID to load events for
    /// - Returns: Array of JSON data objects for each event line, or nil if file doesn't exist
    public func loadSessionEvents(sessionId: String) -> [Data]? {
        let eventsFileURL = sessionsDirectory
            .appendingPathComponent("\(sessionId).jsonl")
        
        guard fileManager.fileExists(atPath: eventsFileURL.path) else {
            return nil
        }
        
        do {
            let content = try String(contentsOf: eventsFileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            var events: [Data] = []
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                
                if let data = trimmed.data(using: .utf8) {
                    events.append(data)
                }
            }
            
            return events
        } catch {
            return nil
        }
    }
    
    /// Get metadata for a single session by ID
    /// - Parameter sessionId: The session ID to load metadata for
    /// - Returns: SessionMetadata if found and valid, nil otherwise
    public func getSessionMetadata(sessionId: String) throws -> SessionMetadata? {
        let metadataFileURL = sessionsDirectory
            .appendingPathComponent("\(sessionId).json")
        
        guard fileManager.fileExists(atPath: metadataFileURL.path) else {
            return nil
        }
        
        return loadSessionMetadata(from: metadataFileURL)
    }
    
    /// Remove the lock file for a session if it exists
    /// - Parameter sessionId: The session ID whose lock file should be removed
    /// - Returns: true if a lock file was found and removed, false otherwise
    @discardableResult
    public func removeSessionLockFile(sessionId: String) -> Bool {
        let lockFileURL = sessionsDirectory
            .appendingPathComponent("\(sessionId).lock")
        
        guard fileManager.fileExists(atPath: lockFileURL.path) else {
            return false
        }
        
        do {
            try fileManager.removeItem(at: lockFileURL)
            print("[SessionStorage] Removed stale lock file for session: \(sessionId)")
            return true
        } catch {
            print("[SessionStorage] Failed to remove lock file for session \(sessionId): \(error)")
            return false
        }
    }
    
    /// Load and reconstruct the conversation history for a session
    /// - Parameter sessionId: The session ID to load history for
    /// - Returns: Array of ChatMessage representing the conversation
    /// - Throws: SessionStorageError if the session cannot be loaded
    public func loadSessionHistory(sessionId: String) throws -> [ChatMessage] {
        guard let eventsData = loadSessionEvents(sessionId: sessionId) else {
            throw SessionStorageError.sessionNotFound(sessionId)
        }
        
        let decoder = JSONDecoder()
        var messages: [ChatMessage] = []
        var currentAssistantContent = ""
        var currentAssistantTimestamp: Date?
        var currentToolCallIds: [String] = []
        
        for eventData in eventsData {
            guard let event = try? decoder.decode(SessionEvent.self, from: eventData) else {
                continue // Skip malformed events
            }
            
            switch event.type {
            case .userMessage:
                // Flush any pending assistant message
                if !currentAssistantContent.isEmpty {
                    messages.append(ChatMessage(
                        role: .assistant,
                        content: currentAssistantContent.trimmingCharacters(in: .whitespacesAndNewlines),
                        timestamp: currentAssistantTimestamp ?? Date(),
                        toolCallIds: currentToolCallIds.isEmpty ? nil : currentToolCallIds
                    ))
                    currentAssistantContent = ""
                    currentAssistantTimestamp = nil
                    currentToolCallIds = []
                }
                
                // Add user message
                if let content = event.content, !content.isEmpty {
                    messages.append(ChatMessage(
                        role: .user,
                        content: content,
                        timestamp: event.timestamp ?? Date()
                    ))
                }
                
            case .agentMessage:
                // Accumulate assistant content (may come in chunks)
                if let content = event.content {
                    if currentAssistantTimestamp == nil {
                        currentAssistantTimestamp = event.timestamp
                    }
                    currentAssistantContent += content
                }
                
            case .toolCall:
                // Track tool call IDs for the current assistant message
                if let toolCallId = event.toolCallId {
                    currentToolCallIds.append(toolCallId)
                }
                
            case .turnEnd:
                // Flush any pending assistant message at turn end
                if !currentAssistantContent.isEmpty {
                    messages.append(ChatMessage(
                        role: .assistant,
                        content: currentAssistantContent.trimmingCharacters(in: .whitespacesAndNewlines),
                        timestamp: currentAssistantTimestamp ?? Date(),
                        toolCallIds: currentToolCallIds.isEmpty ? nil : currentToolCallIds
                    ))
                    currentAssistantContent = ""
                    currentAssistantTimestamp = nil
                    currentToolCallIds = []
                }
                
            case .toolResult, .sessionStart, .sessionEnd, .error, .unknown:
                // These events don't directly contribute to chat messages
                break
            }
        }
        
        // Flush any remaining assistant content
        if !currentAssistantContent.isEmpty {
            messages.append(ChatMessage(
                role: .assistant,
                content: currentAssistantContent.trimmingCharacters(in: .whitespacesAndNewlines),
                timestamp: currentAssistantTimestamp ?? Date(),
                toolCallIds: currentToolCallIds.isEmpty ? nil : currentToolCallIds
            ))
        }
        
        return messages
    }
    
    // MARK: - Private Helpers
    
    private func loadSessionMetadata(from fileURL: URL) -> SessionMetadata? {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            return try decoder.decode(SessionMetadata.self, from: data)
        } catch {
            return nil
        }
    }
}

/// Errors that can occur during session storage operations
public enum SessionStorageError: Error, LocalizedError {
    case sessionNotFound(String)
    case invalidSessionData(String)
    
    public var errorDescription: String? {
        switch self {
        case .sessionNotFound(let sessionId):
            return "Session not found: \(sessionId)"
        case .invalidSessionData(let reason):
            return "Invalid session data: \(reason)"
        }
    }
}
