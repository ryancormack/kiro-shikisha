#if os(macOS)
import SwiftUI

/// View showing list of past sessions for a workspace
public struct SessionHistoryView: View {
    /// The workspace path to show sessions for
    let workspacePath: URL
    
    /// Callback when a session is selected for resuming
    let onSelectSession: (String) -> Void
    
    /// Session storage for loading sessions
    private let sessionStorage: SessionStorage
    
    /// Sessions for this workspace
    @State private var sessions: [SessionMetadata] = []
    
    /// Whether sessions are loading
    @State private var isLoading: Bool = true
    
    /// Error message if loading fails
    @State private var errorMessage: String?
    
    public init(
        workspacePath: URL,
        sessionStorage: SessionStorage = SessionStorage(),
        onSelectSession: @escaping (String) -> Void
    ) {
        self.workspacePath = workspacePath
        self.sessionStorage = sessionStorage
        self.onSelectSession = onSelectSession
    }
    
    public var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading sessions...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Error loading sessions")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        loadSessions()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sessions.isEmpty {
                emptyStateView
            } else {
                sessionListView
            }
        }
        .onAppear {
            loadSessions()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Sessions")
                .font(.headline)
            Text("Start a new conversation to create a session history.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var sessionListView: some View {
        List {
            ForEach(sortedSessions) { session in
                SessionRow(
                    session: session,
                    sessionStorage: sessionStorage,
                    onResume: {
                        onSelectSession(session.sessionId)
                    },
                    onDelete: {
                        deleteSession(session)
                    }
                )
            }
        }
        .listStyle(.inset)
    }
    
    /// Sessions sorted by last activity date (most recent first)
    private var sortedSessions: [SessionMetadata] {
        sessions.sorted { (s1, s2) in
            let date1 = s1.lastActivityDate ?? .distantPast
            let date2 = s2.lastActivityDate ?? .distantPast
            return date1 > date2
        }
    }
    
    private func loadSessions() {
        isLoading = true
        errorMessage = nil
        
        // Load sessions asynchronously to not block UI
        Task {
            let loadedSessions = sessionStorage.getSessionsForWorkspace(path: workspacePath)
            await MainActor.run {
                self.sessions = loadedSessions
                self.isLoading = false
            }
        }
    }
    
    private func deleteSession(_ session: SessionMetadata) {
        // Remove from disk first, then from local state
        _ = sessionStorage.deleteSession(sessionId: session.sessionId)
        sessions.removeAll { $0.sessionId == session.sessionId }
    }
}

#Preview {
    SessionHistoryView(
        workspacePath: URL(fileURLWithPath: "/Users/developer/Projects/MyProject"),
        onSelectSession: { sessionId in
            print("Selected session: \(sessionId)")
        }
    )
    .frame(width: 350, height: 400)
}
#endif
