import Foundation

/// Errors that can occur during Git operations
public enum GitServiceError: Error, Sendable {
    case notAGitRepository
    case commandFailed(command: String, exitCode: Int32, stderr: String)
    case invalidOutput(String)
    case worktreeCreationFailed(String)
    case worktreeRemovalFailed(String)
}

#if os(macOS)
/// Service for performing Git operations using the git command-line tool
public actor GitService {
    
    public init() {}
    
    // MARK: - Repository Detection
    
    /// Detect if a path is inside a Git repository
    /// - Parameter path: The path to check
    /// - Returns: A GitRepository if the path is in a git repo, nil otherwise
    public func detectGitRepository(at path: URL) async throws -> GitRepository? {
        // Check if we're in a git repository by getting the top-level directory
        let rootPathOutput: String
        do {
            rootPathOutput = try await runGitCommand(["rev-parse", "--show-toplevel"], at: path)
        } catch GitServiceError.commandFailed {
            // Not a git repository
            return nil
        }
        
        let rootPath = URL(fileURLWithPath: rootPathOutput.trimmingCharacters(in: .whitespacesAndNewlines))
        
        // Get current branch and remote URL in parallel
        async let branch = getCurrentBranch(at: rootPath)
        async let remote = getRemoteURL(at: rootPath)
        
        return GitRepository(
            rootPath: rootPath,
            remoteURL: try? await remote,
            currentBranch: try? await branch
        )
    }
    
    // MARK: - Worktree Operations
    
    /// List all worktrees for a repository
    /// - Parameter repository: The repository to list worktrees for
    /// - Returns: Array of worktrees, with the main worktree first
    public func listWorktrees(repository: GitRepository) async throws -> [GitWorktree] {
        let output = try await runGitCommand(["worktree", "list", "--porcelain"], at: repository.rootPath)
        return parseWorktreeList(output)
    }
    
    /// Create a new worktree
    /// - Parameters:
    ///   - repository: The repository to create the worktree in
    ///   - branch: The branch name for the new worktree
    ///   - path: The path where the worktree should be created
    /// - Returns: The newly created worktree
    public func createWorktree(repository: GitRepository, branch: String, path: URL) async throws -> GitWorktree {
        // Create the worktree with a new branch
        do {
            _ = try await runGitCommand(["worktree", "add", path.path, "-b", branch], at: repository.rootPath)
        } catch let error as GitServiceError {
            if case .commandFailed(_, _, let stderr) = error {
                throw GitServiceError.worktreeCreationFailed(stderr)
            }
            throw error
        }
        
        // Get the commit hash for the new worktree
        let commitHash = try await runGitCommand(["rev-parse", "HEAD"], at: path)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return GitWorktree(
            path: path,
            branch: branch,
            commitHash: commitHash,
            isMain: false
        )
    }
    
    /// Remove a worktree
    /// - Parameter path: The path of the worktree to remove
    public func removeWorktree(path: URL) async throws {
        // First, find the repository root by going to parent and checking
        let parentPath = path.deletingLastPathComponent()
        
        do {
            _ = try await runGitCommand(["worktree", "remove", path.path], at: parentPath)
        } catch let error as GitServiceError {
            if case .commandFailed(_, _, let stderr) = error {
                throw GitServiceError.worktreeRemovalFailed(stderr)
            }
            throw error
        }
    }
    
    // MARK: - Branch and Remote Info
    
    /// Get the current branch at a path
    /// - Parameter path: The path to check
    /// - Returns: The current branch name, or nil if detached HEAD
    public func getCurrentBranch(at path: URL) async throws -> String? {
        let output = try await runGitCommand(["rev-parse", "--abbrev-ref", "HEAD"], at: path)
        let branch = output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // "HEAD" means detached HEAD state
        return branch == "HEAD" ? nil : branch
    }
    
    /// Get the remote URL for origin
    /// - Parameter path: The path to the repository
    /// - Returns: The remote URL, or nil if no origin remote
    public func getRemoteURL(at path: URL) async throws -> URL? {
        do {
            let output = try await runGitCommand(["remote", "get-url", "origin"], at: path)
            let urlString = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return URL(string: urlString)
        } catch GitServiceError.commandFailed {
            // No origin remote configured
            return nil
        }
    }
    
    // MARK: - Private Helpers
    
    /// Run a git command and capture output
    /// - Parameters:
    ///   - args: Arguments to pass to git
    ///   - path: Working directory for the command
    /// - Returns: The standard output from the command
    private func runGitCommand(_ args: [String], at path: URL) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = path
        
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        
        try process.run()
        process.waitUntilExit()
        
        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        
        let stdoutString = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrString = String(data: stderrData, encoding: .utf8) ?? ""
        
        guard process.terminationStatus == 0 else {
            throw GitServiceError.commandFailed(
                command: "git \(args.joined(separator: " "))",
                exitCode: process.terminationStatus,
                stderr: stderrString
            )
        }
        
        return stdoutString
    }
    
    /// Parse the porcelain output of 'git worktree list'
    /// Format:
    /// worktree /path/to/main
    /// HEAD abc123
    /// branch refs/heads/main
    ///
    /// worktree /path/to/linked
    /// HEAD def456
    /// branch refs/heads/feature
    private func parseWorktreeList(_ output: String) -> [GitWorktree] {
        var worktrees: [GitWorktree] = []
        var currentPath: URL?
        var currentCommit: String?
        var currentBranch: String?
        
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if line.hasPrefix("worktree ") {
                // Save previous worktree if we have one
                if let path = currentPath, let commit = currentCommit {
                    worktrees.append(GitWorktree(
                        path: path,
                        branch: currentBranch ?? "HEAD",
                        commitHash: commit,
                        isMain: worktrees.isEmpty
                    ))
                }
                
                // Start new worktree
                let pathString = String(line.dropFirst("worktree ".count))
                currentPath = URL(fileURLWithPath: pathString)
                currentCommit = nil
                currentBranch = nil
            } else if line.hasPrefix("HEAD ") {
                currentCommit = String(line.dropFirst("HEAD ".count))
            } else if line.hasPrefix("branch ") {
                // Branch is in format refs/heads/branchname
                let fullRef = String(line.dropFirst("branch ".count))
                if fullRef.hasPrefix("refs/heads/") {
                    currentBranch = String(fullRef.dropFirst("refs/heads/".count))
                } else {
                    currentBranch = fullRef
                }
            }
        }
        
        // Don't forget the last worktree
        if let path = currentPath, let commit = currentCommit {
            worktrees.append(GitWorktree(
                path: path,
                branch: currentBranch ?? "HEAD",
                commitHash: commit,
                isMain: worktrees.isEmpty
            ))
        }
        
        return worktrees
    }
}
#else
// Linux stub - Git operations require macOS Process APIs
public actor GitService {
    
    public init() {}
    
    public func detectGitRepository(at path: URL) async throws -> GitRepository? {
        return nil
    }
    
    public func listWorktrees(repository: GitRepository) async throws -> [GitWorktree] {
        return []
    }
    
    public func createWorktree(repository: GitRepository, branch: String, path: URL) async throws -> GitWorktree {
        throw GitServiceError.commandFailed(command: "git", exitCode: 1, stderr: "Not supported on Linux")
    }
    
    public func removeWorktree(path: URL) async throws {
        throw GitServiceError.commandFailed(command: "git", exitCode: 1, stderr: "Not supported on Linux")
    }
    
    public func getCurrentBranch(at path: URL) async throws -> String? {
        return nil
    }
    
    public func getRemoteURL(at path: URL) async throws -> URL? {
        return nil
    }
}
#endif
