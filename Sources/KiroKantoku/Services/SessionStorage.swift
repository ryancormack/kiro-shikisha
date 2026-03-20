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
        
        print("[SessionStorage] Loading events from: \(eventsFileURL.path)")
        
        guard fileManager.fileExists(atPath: eventsFileURL.path) else {
            print("[SessionStorage] Events file does not exist: \(eventsFileURL.path)")
            return nil
        }
        
        print("[SessionStorage] Events file exists: \(eventsFileURL.path)")
        
        do {
            let content = try String(contentsOf: eventsFileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            print("[SessionStorage] Found \(nonEmptyLines.count) non-empty lines in JSONL file")
            
            var events: [Data] = []
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                
                if let data = trimmed.data(using: .utf8) {
                    events.append(data)
                }
            }
            
            print("[SessionStorage] Created \(events.count) Data objects from JSONL lines")
            return events
        } catch {
            print("[SessionStorage] Failed to read events file: \(error)")
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
        
        print("[SessionStorage] loadSessionHistory: received \(eventsData.count) events for session \(sessionId)")
        
        let decoder = JSONDecoder()
        var messages: [ChatMessage] = []
        var currentAssistantContent = ""
        var currentAssistantTimestamp: Date?
        var currentToolCallIds: [String] = []
        var decodedCount = 0
        var skippedCount = 0
        var eventTypeCounts: [String: Int] = [:]
        
        for eventData in eventsData {
            let event: SessionEvent
            do {
                event = try decoder.decode(SessionEvent.self, from: eventData)
            } catch {
                skippedCount += 1
                if skippedCount <= 3 {
                    let rawSample = String(data: eventData, encoding: .utf8)?.prefix(200) ?? "(not UTF-8)"
                    print("[SessionStorage] Failed to decode event: \(error). Raw JSON sample: \(rawSample)")
                }
                continue
            }
            
            decodedCount += 1
            eventTypeCounts[event.kind.rawValue, default: 0] += 1
            
            switch event.kind {
            case .prompt:
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
                let text = event.data.extractTextContent()
                if !text.isEmpty {
                    messages.append(ChatMessage(
                        role: .user,
                        content: text,
                        timestamp: Date()
                    ))
                }
                
            case .assistantMessage:
                // Accumulate assistant content
                let text = event.data.extractTextContent()
                if !text.isEmpty {
                    if currentAssistantTimestamp == nil {
                        currentAssistantTimestamp = Date()
                    }
                    currentAssistantContent += text
                }
                
            case .toolUse:
                // Extract toolUseId from content items where kind == "toolUse"
                if let contentItems = event.data.content {
                    for item in contentItems {
                        if item.kind == "toolUse", let data = item.data, case .object(let dict) = data {
                            if let toolUseIdValue = dict["toolUseId"], let toolUseId = toolUseIdValue.stringValue {
                                currentToolCallIds.append(toolUseId)
                            }
                        }
                    }
                }
                
            case .toolResults, .unknown:
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
        
        print("[SessionStorage] loadSessionHistory summary: \(decodedCount) decoded, \(skippedCount) skipped, \(messages.count) ChatMessages reconstructed. Event types: \(eventTypeCounts)")
        
        return messages
    }
    
    /// Load session history with workspace-based fallback
    /// If the given session has no history, tries other sessions for the same workspace
    /// - Parameters:
    ///   - sessionId: The primary session ID to try first
    ///   - workspacePath: The workspace path to find alternative sessions
    /// - Returns: Array of ChatMessage, or empty array if nothing found
    public func loadSessionHistoryWithWorkspaceFallback(sessionId: String, workspacePath: URL) -> [ChatMessage] {
        let result = loadSessionHistoryWithWorkspaceFallbackResult(sessionId: sessionId, workspacePath: workspacePath)
        return result.messages
    }

    /// Result of loading session history with workspace fallback, including the effective session ID
    public struct SessionHistoryResult {
        /// The loaded chat messages
        public let messages: [ChatMessage]
        /// The session ID that the messages came from, or nil if no messages were found.
        /// This may differ from the requested sessionId if a workspace fallback was used.
        public let effectiveSessionId: String?
    }

    /// Load session history with workspace-based fallback, returning the effective session ID
    /// If the given session has no history, tries other sessions for the same workspace
    /// - Parameters:
    ///   - sessionId: The primary session ID to try first
    ///   - workspacePath: The workspace path to find alternative sessions
    /// - Returns: SessionHistoryResult containing messages and the effective session ID
    public func loadSessionHistoryWithWorkspaceFallbackResult(sessionId: String, workspacePath: URL) -> SessionHistoryResult {
        print("[SessionStorage] loadSessionHistoryWithWorkspaceFallback: sessionId=\(sessionId), workspace=\(workspacePath.path)")
        
        // First try the given session ID
        do {
            let messages = try loadSessionHistory(sessionId: sessionId)
            if !messages.isEmpty {
                print("[SessionStorage] Found \(messages.count) messages from primary session \(sessionId)")
                return SessionHistoryResult(messages: messages, effectiveSessionId: sessionId)
            }
            print("[SessionStorage] Primary session \(sessionId) exists but has no messages")
        } catch {
            print("[SessionStorage] Primary session \(sessionId) failed: \(error)")
        }
        
        // Fallback: find other sessions for the same workspace
        print("[SessionStorage] Trying workspace-based fallback for: \(workspacePath.path)")
        let workspaceSessions = getSessionsForWorkspace(path: workspacePath)
        print("[SessionStorage] Found \(workspaceSessions.count) sessions for workspace")
        
        // Sort by lastModified descending (newest first)
        let sortedSessions = workspaceSessions.sorted { a, b in
            (a.lastModified ?? .distantPast) > (b.lastModified ?? .distantPast)
        }
        
        // Filter out the session we already tried
        let candidates = sortedSessions.filter { $0.sessionId != sessionId }
        print("[SessionStorage] \(candidates.count) candidate sessions after filtering out \(sessionId)")
        
        for candidate in candidates {
            print("[SessionStorage] Trying fallback session: \(candidate.sessionId)")
            do {
                let messages = try loadSessionHistory(sessionId: candidate.sessionId)
                if !messages.isEmpty {
                    print("[SessionStorage] Workspace fallback found \(messages.count) messages from session \(candidate.sessionId)")
                    return SessionHistoryResult(messages: messages, effectiveSessionId: candidate.sessionId)
                }
                print("[SessionStorage] Fallback session \(candidate.sessionId) has no messages")
            } catch {
                print("[SessionStorage] Fallback session \(candidate.sessionId) failed: \(error)")
            }
        }
        
        print("[SessionStorage] No chat history found via workspace fallback")
        return SessionHistoryResult(messages: [], effectiveSessionId: nil)
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
