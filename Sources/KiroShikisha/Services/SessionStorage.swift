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
    
    /// Canonical path of cwd for comparison - resolves symlinks and standardizes the path
    public var cwdCanonical: String {
        URL(fileURLWithPath: cwd).resolvingSymlinksInPath().standardizedFileURL.path
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
        let workspaceCanonical = canonicalPath(path.path)
        
        return allSessions.filter { session in
            // Use canonical paths for comparison to handle symlinks and standardization
            return session.cwdCanonical == workspaceCanonical
        }
    }
    
    /// Verify if a session's cwd matches a given workspace path using canonical comparison
    /// - Parameters:
    ///   - sessionId: The session ID to check
    ///   - workspacePath: The workspace path to compare against
    /// - Returns: True if the session's cwd matches the workspace path
    public func sessionMatchesWorkspacePath(sessionId: String, workspacePath: URL) -> Bool {
        guard let metadata = try? getSessionMetadata(sessionId: sessionId) else {
            return false
        }
        let workspaceCanonical = canonicalPath(workspacePath.path)
        return metadata.cwdCanonical == workspaceCanonical
    }
    
    // MARK: - Path Helpers
    
    /// Convert a path string to its canonical form (resolved symlinks and standardized)
    /// - Parameter path: The path string to canonicalize
    /// - Returns: The canonical path string
    public func canonicalPath(_ path: String) -> String {
        return URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }
    
    /// Load session events from a JSONL file
    /// - Parameter sessionId: The session ID to load events for
    /// - Returns: Array of JSON data objects for each valid event line, or nil if file doesn't exist
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
            var lineNumber = 0
            for line in lines {
                lineNumber += 1
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                
                guard let data = trimmed.data(using: .utf8) else {
                    print("[SessionStorage] Session \(sessionId) line \(lineNumber): Failed to convert to UTF-8 data, skipping")
                    continue
                }
                
                // Validate that the line is valid JSON before including it
                do {
                    _ = try JSONSerialization.jsonObject(with: data, options: [])
                    events.append(data)
                } catch {
                    print("[SessionStorage] Session \(sessionId) line \(lineNumber): Invalid JSON, skipping - \(error.localizedDescription)")
                    continue
                }
            }
            
            return events
        } catch {
            print("[SessionStorage] Failed to read events file for session \(sessionId): \(error.localizedDescription)")
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
    
    /// Load and reconstruct the conversation history for a session
    /// - Parameter sessionId: The session ID to load history for
    /// - Returns: Array of ChatMessage representing the conversation
    /// - Throws: SessionStorageError if the session cannot be loaded
    public func loadSessionHistory(sessionId: String) throws -> [ChatMessage] {
        guard let eventsData = loadSessionEvents(sessionId: sessionId) else {
            throw SessionStorageError.sessionNotFound(sessionId)
        }
        
        // Handle empty events - return empty array
        if eventsData.isEmpty {
            return []
        }
        
        let decoder = JSONDecoder()
        var messages: [ChatMessage] = []
        var currentAssistantContent = ""
        var currentAssistantTimestamp: Date?
        var currentToolCallIds: [String] = []
        
        for (index, eventData) in eventsData.enumerated() {
            guard let event = try? decoder.decode(SessionEvent.self, from: eventData) else {
                print("[SessionStorage] Session \(sessionId) event \(index): Failed to decode as SessionEvent, skipping")
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
                
                // Add user message - handle nil or empty content gracefully
                let content = event.content ?? ""
                if !content.isEmpty {
                    messages.append(ChatMessage(
                        role: .user,
                        content: content,
                        timestamp: event.timestamp ?? Date()
                    ))
                }
                
            case .agentMessage:
                // Accumulate assistant content (may come in chunks)
                // Handle nil content gracefully
                if let content = event.content {
                    if currentAssistantTimestamp == nil {
                        currentAssistantTimestamp = event.timestamp
                    }
                    currentAssistantContent += content
                }
                
            case .toolCall:
                // Track tool call IDs for the current assistant message
                if let toolCallId = event.toolCallId, !toolCallId.isEmpty {
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
                // Unknown event types are handled gracefully via the .unknown case
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
            let metadata = try decoder.decode(SessionMetadata.self, from: data)
            
            // Validate required fields
            if metadata.sessionId.isEmpty {
                print("[SessionStorage] Invalid metadata at \(fileURL.path): session_id is empty")
                return nil
            }
            if metadata.cwd.isEmpty {
                print("[SessionStorage] Invalid metadata at \(fileURL.path): cwd is empty")
                return nil
            }
            
            return metadata
        } catch let error as DecodingError {
            switch error {
            case .keyNotFound(let key, _):
                print("[SessionStorage] Missing required field '\(key.stringValue)' in metadata at \(fileURL.path)")
            case .typeMismatch(let type, let context):
                print("[SessionStorage] Type mismatch for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: ".")) in \(fileURL.path)")
            case .valueNotFound(let type, let context):
                print("[SessionStorage] Missing value for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: ".")) in \(fileURL.path)")
            case .dataCorrupted(let context):
                print("[SessionStorage] Corrupted data at \(context.codingPath.map(\.stringValue).joined(separator: ".")) in \(fileURL.path): \(context.debugDescription)")
            @unknown default:
                print("[SessionStorage] Unknown decoding error in \(fileURL.path): \(error)")
            }
            return nil
        } catch {
            print("[SessionStorage] Failed to read metadata at \(fileURL.path): \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Session Validation
    
    /// Validate a session by checking its metadata and events files
    /// - Parameter sessionId: The session ID to validate
    /// - Returns: SessionValidationResult indicating if session is valid, invalid, or not found
    public func validateSession(sessionId: String) -> SessionValidationResult {
        let metadataFileURL = sessionsDirectory.appendingPathComponent("\(sessionId).json")
        
        // Check if metadata file exists
        guard fileManager.fileExists(atPath: metadataFileURL.path) else {
            return .notFound
        }
        
        // Try to load and validate metadata
        guard let metadata = loadSessionMetadata(from: metadataFileURL) else {
            return .invalid(reason: "Failed to decode metadata JSON")
        }
        
        // Validate session_id matches filename
        if metadata.sessionId != sessionId {
            return .invalid(reason: "session_id '\(metadata.sessionId)' does not match filename '\(sessionId)'")
        }
        
        // Validate cwd is non-empty
        if metadata.cwd.isEmpty {
            return .invalid(reason: "cwd field is empty")
        }
        
        // Check events file existence (optional - session may have no events yet)
        let eventsFileURL = sessionsDirectory.appendingPathComponent("\(sessionId).jsonl")
        if fileManager.fileExists(atPath: eventsFileURL.path) {
            // Verify the events file is readable (basic check)
            do {
                _ = try Data(contentsOf: eventsFileURL)
            } catch {
                return .invalid(reason: "Events file exists but cannot be read: \(error.localizedDescription)")
            }
        }
        
        return .valid
    }
    
    /// Check if a session exists and is valid
    /// - Parameter sessionId: The session ID to check
    /// - Returns: True if the session exists and passes basic validation
    public func sessionExists(sessionId: String) -> Bool {
        return validateSession(sessionId: sessionId) == .valid
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

/// Result of session validation
public enum SessionValidationResult: Sendable, Equatable {
    case valid
    case invalid(reason: String)
    case notFound
}
