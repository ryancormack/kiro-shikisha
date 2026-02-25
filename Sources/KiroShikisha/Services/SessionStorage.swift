import Foundation

/// Metadata for a stored Kiro session
public struct SessionMetadata: Codable, Identifiable, Sendable {
    /// The session identifier
    public let sessionId: String
    /// Working directory for the session
    public let cwd: String
    /// When the session was created
    public let createdAt: Date?
    /// When the session was last modified
    public let lastModified: Date?
    
    public var id: String { sessionId }
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd
        case createdAt = "created_at"
        case lastModified = "last_modified"
    }
    
    public init(
        sessionId: String,
        cwd: String,
        createdAt: Date? = nil,
        lastModified: Date? = nil
    ) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        sessionId = try container.decode(String.self, forKey: .sessionId)
        cwd = try container.decode(String.self, forKey: .cwd)
        
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
    private let fileManager: FileManager
    
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
