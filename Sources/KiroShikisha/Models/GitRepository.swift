import Foundation

/// Represents a Git repository detected in the filesystem
public struct GitRepository: Identifiable, Equatable, Sendable {
    /// Unique identifier for this repository instance
    public let id: UUID
    /// The root path of the repository (.git parent directory)
    public let rootPath: URL
    /// Remote URL for origin, if configured
    public let remoteURL: URL?
    /// Currently checked out branch, if any
    public let currentBranch: String?
    
    public init(
        id: UUID = UUID(),
        rootPath: URL,
        remoteURL: URL? = nil,
        currentBranch: String? = nil
    ) {
        self.id = id
        self.rootPath = rootPath
        self.remoteURL = remoteURL
        self.currentBranch = currentBranch
    }
}
